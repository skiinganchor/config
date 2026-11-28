{ config, hermes-agent, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.homelab.services.hermes-agent;
  profileFields = [ "config" "env" "auth" "cron" "garmin" "skills" "legacyProviders" "legacySkills" ];
  profileData =
    if !cfg.enable then { }
    else if !builtins.pathExists cfg.profilesFile then
      throw "The locked config-private input is missing the Hermes profile file. Update the my-secrets input."
    else
      let
        encryptedJson = pkgs.runCommand "hermes-encrypted-profiles.json" { nativeBuildInputs = [ pkgs.yq-go ]; } ''
          yq -o=json '.' ${lib.escapeShellArg cfg.profilesFile} > "$out"
        '';
        parsed = builtins.tryEval (builtins.fromJSON (builtins.readFile encryptedJson));
        document = parsed.value;
        data = document.hermes.profiles or null;
        validateProfile = name: fields:
          if builtins.match "[a-z0-9]+(-[a-z0-9]+)*" name == null || builtins.stringLength name > 24 then
            throw "Invalid Hermes profile name ${name}."
          else if !builtins.isAttrs fields then
            throw "Hermes profile ${name} must contain config and env fields; its value is empty or is not a mapping."
          else if !(fields ? config) || !(fields ? env) then
            throw "Hermes profile ${name} must contain both config and env fields."
          else if !(lib.all
            (key: (lib.elem key profileFields || (name == "default" && key == "model"))
              && builtins.isString fields.${key}
              && (lib.hasPrefix "ENC[AES256_GCM," fields.${key}
              || (key == "env" && fields.${key} == "")))
            (builtins.attrNames fields)) then
            throw "Hermes profile ${name} contains an unsupported field or an unencrypted value."
          else fields;
      in
      if !parsed.success || !(document ? sops.mac) || !builtins.isAttrs data || data == { } then
        throw "The Hermes profile file must contain named, SOPS-encrypted profiles with config and env fields."
      else lib.mapAttrs validateProfile data;
  names = builtins.attrNames profileData;
  backendProfile =
    if profileData ? default then "default"
    else if builtins.length names == 1 then builtins.head names
    else null;
  profiles = lib.mapAttrs
    (name: fields: {
      stateDirectory = "hermes${suffix name}";
      inherit (cfg) garmin;
      backend = cfg.backend // lib.optionalAttrs (name != backendProfile) { mode = "none"; };
      secretKeys = lib.mapAttrs (key: _: "hermes/profiles/${name}/${key}") fields
        // lib.optionalAttrs (profileData ? default.model) { model = "hermes/profiles/default/model"; };
    })
    profileData;
  suffix = name: lib.optionalString (name != "default") "-${name}";
  account = "hermes";
  gateway = name: "hermes-agent${suffix name}";
  backend = name: "hermes-backend${suffix name}";
  units = lib.optional cfg.gateway.enable (gateway backendProfile)
    ++ lib.optional (cfg.backend.mode != "none") (backend backendProfile);
  secretName = name: key: "hermes-profiles/${name}/${key}";
  secretPath = name: key: config.sops.secrets.${secretName name key}.path;
  hermes = "${cfg.package}/bin/hermes";
  garminLauncher = command: pkgs.writeShellScriptBin command ''
    set -eu
    umask 077
    case "''${HERMES_HOME:?Set HERMES_HOME}" in
      /var/lib/hermes/.hermes/profiles/*)
        export GARMINTOKENS="/var/lib/hermes-''${HERMES_HOME##*/}/.garminconnect"
        ;;
      *) export GARMINTOKENS="$HERMES_HOME/../.garminconnect" ;;
    esac
    export PATH=${lib.makeBinPath [ pkgs.git ]}:"$PATH"
    exec ${pkgs.uv}/bin/uvx --python ${pkgs.python312}/bin/python3 \
      --from git+https://github.com/Taxuspt/garmin_mcp@202913fde53c9d15890d661fc9748dc6d0d5af52 ${command} "$@"
  '';
  garminPackages = [ (garminLauncher "garmin-mcp") (garminLauncher "garmin-mcp-auth") ];
  runtimePath = profile: [ cfg.package pkgs.bash pkgs.coreutils pkgs.git pkgs.systemd ]
    ++ lib.optionals profile.garmin.enable garminPackages;
  state = profile: "/var/lib/${profile.stateDirectory}";
  profileHome = name: profile:
    if name == "default" || !(profileData ? default) then "${state profile}/.hermes"
    else "/var/lib/hermes/.hermes/profiles/${name}";
  profileEnvironment = name: profile: {
    HOME = state profile;
    HERMES_HOME = profileHome name profile;
    HERMES_MANAGED = "NixOS";
  };
  secrets = name: profile:
    let
      common = key: {
        owner = account;
        group = account;
        mode = "0400";
        restartUnits = map (unit: "${unit}.service") (
          if key == "cron" then lib.optional cfg.gateway.enable (gateway backendProfile)
          else units
        );
      };
    in
    lib.mapAttrs'
      (key: value: lib.nameValuePair (secretName name key) (common key // {
        key = value;
        sopsFile = cfg.profilesFile;
        format = "yaml";
      }))
      profile.secretKeys;
  prepareArgs = name: profile: isGateway:
    [ "--config" (secretPath name "config") "--env" (secretPath name "env") ]
    ++ lib.concatMap (key: lib.optionals (builtins.hasAttr key profile.secretKeys) [ "--${key}" (secretPath name key) ])
      ([ "auth" "garmin" "legacyProviders" "legacySkills" "model" ] ++ lib.optional isGateway "cron")
    ++ lib.optional isGateway "--reconcile-cron"
    ++ lib.optionals (profile.secretKeys ? skills) [ "--skills-base64" (secretPath name "skills") ];
  # Keep imports together in the store so the single entry point can load the
  # compatibility adapter while a profile still uses legacy inputs.
  prepare = pkgs.runCommand "hermes-profile-preparation" { } ''
    mkdir -p "$out"
    cp ${./prepare-profile.py} "$out/prepare-profile.py"
    cp ${./reconcile-cron-jobs.py} "$out/reconcile_cron.py"
    cp ${./reconcile-skills.py} "$out/legacy_skills.py"
  '';
  stateDirectories = map (profile: profile.stateDirectory) (builtins.attrValues profiles);
  prepareProfiles = isGateway: pkgs.writeShellScript "hermes-prepare-profiles" ''
    set -eu
    exec 9>${state profiles.${backendProfile}}/.profile-layout.lock
    ${pkgs.util-linux}/bin/flock 9
    ${lib.concatMapStringsSep "\n" (name:
      let profile = profiles.${name}; in ''
        HOME=${lib.escapeShellArg (state profile)} HERMES_HOME=${lib.escapeShellArg (profileHome name profile)} \
          ${cfg.package.hermesVenv}/bin/python3 ${prepare}/prepare-profile.py \
          ${lib.escapeShellArgs ([ "--state-directory" (state profile) ] ++ prepareArgs name profile isGateway)}
      '') ([ backendProfile ] ++ lib.remove backendProfile names)}
  '';
  service = name: profile: isGateway: args:
    let
      unit = if isGateway then gateway name else backend name;
      start = pkgs.writeShellScript "${unit}-start" ''
        set -eu
        cd ${lib.escapeShellArg "${state profile}/workspace"}
        exec ${lib.escapeShellArgs ([ hermes ] ++ args)} >> "$HERMES_HOME/logs/${unit}.service.log" 2>&1
      '';
    in
    {
      description = "Hermes ${if isGateway then "gateway" else "backend"} (${name})";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ] ++ lib.optional isGateway "linger-users.service";
      requires = lib.optional config.sops.useSystemdActivation "sops-install-secrets.service";
      after = [ "network-online.target" ] ++ lib.optional isGateway "linger-users.service"
        ++ lib.optional config.sops.useSystemdActivation "sops-install-secrets.service";
      environment = profileEnvironment name profile;
      path = runtimePath profile;
      preStart = ''
        ${prepareProfiles isGateway}
      '' + lib.optionalString isGateway ''
        for _ in $(seq 1 50); do
          [ -S "/run/user/$(id -u)/bus" ] && exit 0
          sleep 0.2
        done
        echo "Hermes gateway found no user bus for restart-safe cron dispatch" >&2
      '';
      serviceConfig = {
        User = account;
        Group = account;
        StateDirectory = stateDirectories;
        StateDirectoryMode = "0700";
        UMask = "0077";
        ExecStart = start;
        Restart = "on-failure";
        RestartSec = "5s";
        NoNewPrivileges = true;
        LimitCORE = 0;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };
  profileUser = {
    isSystemUser = true;
    group = account;
    home = "/var/lib/hermes";
    shell = pkgs.bashInteractive;
    linger = cfg.gateway.enable;
    packages = lib.optionals cfg.garmin.enable garminPackages;
  };
  profileUnits = name: profile: lib.optionalAttrs (name == backendProfile && cfg.gateway.enable)
    {
      ${gateway name} = service name profile true [ "gateway" ];
    } // lib.optionalAttrs (profile.backend.mode != "none") {
    ${backend name} = service name profile false [
      profile.backend.mode
      "--host"
      profile.backend.host
      "--port"
      (toString profile.backend.port)
      "--no-open"
    ];
  };
  profileCli = name: profile:
    pkgs.writeShellScriptBin "hermes${suffix name}" ''
      set -eu
      umask 077
      if [ "$(id -un)" != ${lib.escapeShellArg (account)} ]; then
        if [ "$(id -u)" != 0 ]; then
          echo "Run sudo hermes${suffix name} to use this system profile." >&2
          exit 1
        fi
        exec ${pkgs.util-linux}/bin/runuser -u ${lib.escapeShellArg (account)} -- "$0" "$@"
      fi
      export ${lib.escapeShellArgs (lib.mapAttrsToList (key: value: "${key}=${value}") (profileEnvironment name profile))}
      export PATH=${lib.makeBinPath (runtimePath profile)}:"$PATH"
      cd ${lib.escapeShellArg "${state profile}/workspace"}
      exec ${hermes} "$@"
    '';
in
{
  options.homelab.services.hermes-agent = {
    enable = mkEnableOption "Hermes Agent profiles";
    url = mkOption {
      type = types.str;
      default = "hermes.${config.homelab.baseDomain}";
    };
    addToSystemPackages = mkEnableOption "profile-aware Hermes CLI launchers";
    package = mkOption {
      type = types.package;
      default = hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
      description = "Hermes Agent package for all profiles on this machine.";
    };
    profilesFile = mkOption {
      type = types.str;
      description = "Absolute path to the SOPS YAML file containing hermes.profiles.";
    };
    gateway.enable = mkEnableOption "the shared Hermes gateway" // { default = true; };
    garmin.enable = mkEnableOption "the pinned Garmin MCP launcher and login helper";
    backend = {
      mode = mkOption {
        type = types.enum [ "none" "serve" "dashboard" ];
        default = "none";
        description = "Hermes backend command for the primary profile.";
      };
      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Hermes backend listen address.";
      };
      port = mkOption {
        type = types.ints.between 1 65535;
        default = 9119;
        description = "Hermes backend listen port.";
      };
    };
    monitoredServices = mkOption {
      type = types.listOf types.str;
      default = lib.optionals (backendProfile != null) units;
      description = "Hermes units shown in the MOTD.";
    };
  };

  config = mkIf cfg.enable {
    services.nginx.virtualHosts = mkIf (cfg.backend.mode != "none") {
      "${cfg.url}" = {
        forceSSL = true;
        enableACME = false;
        extraConfig = ''
          add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
          add_header X-XSS-Protection "1; mode=block" always;
        '';
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.backend.port}";
          proxyWebsockets = true;
        };
        sslCertificate = "/var/lib/acme/${config.homelab.baseDomain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${config.homelab.baseDomain}/key.pem";
      };
    };

    users.groups.${account} = { };
    users.users.${account} = profileUser;
    sops.secrets = lib.concatMapAttrs secrets profiles;
    systemd.services = lib.concatMapAttrs profileUnits profiles;
    environment.systemPackages = lib.optionals cfg.addToSystemPackages (lib.mapAttrsToList profileCli profiles);
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.profilesFile;
        message = "The Hermes profile file must use an absolute path.";
      }
      {
        assertion = backendProfile != null;
        message = "Multiple Hermes profiles require the default profile.";
      }
    ] ++ lib.concatLists (lib.mapAttrsToList
      (name: profile: [
        {
          assertion = cfg.gateway.enable || cfg.backend.mode != "none";
          message = "Hermes profile ${name} must enable a gateway or a backend.";
        }
        {
          assertion = !(profile.secretKeys ? skills && profile.secretKeys ? legacySkills)
            && !(profile.secretKeys ? auth && profile.secretKeys ? legacyProviders);
          message = "Hermes profile ${name} must select a single source for skills and OAuth seeds.";
        }
        {
          assertion = !(profile.secretKeys ? garmin) || cfg.garmin.enable;
          message = "Enable Garmin to use a Garmin seed for Hermes profile ${name}.";
        }
      ])
      profiles);
  };
}
