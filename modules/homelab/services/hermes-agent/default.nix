{ config, hermes-agent, lib, pkgs, ... }:
let
  service = "hermes-agent";
  cfg = config.homelab.services.${service};
  reconcileProviders = ''
    ${config.services.hermes-agent.package.hermesVenv}/bin/python3 \
      ${./reconcile-providers.py} ${lib.escapeShellArg cfg.providersFile} ${lib.escapeShellArg (toString cfg.environmentFile)}
  '';
  # Upstream normalizes mcpServers into settings.mcp_servers, but configFile
  # bypasses its generated settings file. Only overlay the MCP definitions.
  mcpServers = config.services.hermes-agent.settings.mcp_servers or { };
  mergeMcpConfig = cfg.configFile != null && mcpServers != { };
  mcpConfig = pkgs.writeText "hermes-mcp-servers.json" (builtins.toJSON mcpServers);
  mergeMcp = ''
    ${config.services.hermes-agent.package.hermesVenv}/bin/python3 \
      ${./merge-mcp-config.py} ${mcpConfig}
  '';
  garminArgs = [
    "--python"
    "${pkgs.python312}/bin/python3"
    "--from"
    "git+https://github.com/Taxuspt/garmin_mcp@${cfg.mcp.garmin.revision}"
  ];
  garminAuth = pkgs.writeShellScriptBin "hermes-garmin-auth" ''
    set -eu
    umask 0077
    export GARMINTOKENS=${lib.escapeShellArg "${cfg.stateDir}/.garminconnect"}
    export PATH=${lib.makeBinPath [ pkgs.git ]}:"$PATH"
    exec ${pkgs.uv}/bin/uvx ${lib.escapeShellArgs garminArgs} garmin-mcp-auth "$@"
  '';
  garminTokenSetup = lib.optionalString (cfg.mcp.garmin.tokensFile != null) ''
    tokenDir=${lib.escapeShellArg "${cfg.stateDir}/.garminconnect"}
    install -d -m 0700 "$tokenDir"
    tokenTemp=$(mktemp "$tokenDir/.sops-tokens.XXXXXX")
    trap 'rm -f "$tokenTemp"' EXIT
    install -m 0600 ${lib.escapeShellArg cfg.mcp.garmin.tokensFile} "$tokenTemp"
    mv -f "$tokenTemp" "$tokenDir/garmin_tokens.json"
    trap - EXIT
  '';
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption service;

    addToSystemPackages = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Add the hermes CLI to environment.systemPackages and export
        HERMES_HOME system-wide (via environment.variables) so interactive
        shells share state with the gateway service.
      '';
    };

    # none is recommended to keep only configuration as code
    backend = lib.mkOption {
      type = lib.types.submodule {
        options = {
          mode = lib.mkOption {
            type = lib.types.enum [ "none" "serve" "dashboard" ];
            default = "none";
          };

          host = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1";
          };

          port = lib.mkOption {
            type = lib.types.port;
            default = 9119;
          };
        };
      };
      default = { };
      description = "Hermes API and dashboard backend configuration";
    };

    monitoredServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "hermes-agent" ] ++ lib.optionals (cfg.backend.mode != "none") [ "hermes-backend" ];
      description = "Systemd services to show in the MOTD status list";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
      description = "Hermes Agent package to run";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/hermes";
      description = "Persistent state directory for Hermes Agent";
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = "Environment file containing Matrix and integration secrets; use providersFile for model providers";
      example = lib.literalExpression ''
        pkgs.writeText "hermes-env" '''
          # Matrix configs
          MATRIX_E2EE_MODE=required|optional|off
          MATRIX_HOMESERVER=https://matrix.some.domain
          MATRIX_ACCESS_TOKEN=sometoken
          MATRIX_DEVICE_ID=someid
          MATRIX_USER_ID=@hermes:your-server.org
          # Security: restrict who can interact with the bot
          MATRIX_ALLOWED_USERS=@alice:matrix.example.org
          # Optional: restrict which rooms can trigger the bot
          MATRIX_ALLOWED_ROOMS=!abc123:matrix.example.org
          # Optional: by default, Hermes requires an @mention to respond
          MATRIX_REQUIRE_MENTION=false
        '''
      '';
    };

    cronJobsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = lib.literalExpression ''config.sops.secrets."hermes/cron-jobs".path'';
      description = ''
        Absolute runtime path to a JSON list of recurring jobs. Each entry has
        a stable id, name, schedule, deliver (matrix:ROOM_ID), and prompt.
        Use a sops-nix secret to keep all fields out of the Nix store.
        Jobs are reconciled before gateway startup; an empty list removes
        managed jobs while leaving jobs created interactively untouched.
        See docs/hermes-cron-jobs.md for the schema and SOPS configuration.
      '';
    };

    skillsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = lib.literalExpression ''config.sops.secrets."hermes/skills".path'';
      description = ''
        Absolute runtime path to a private JSON list of skills. Each entry has
        a name, category, and map of relative filenames to text contents.
        Reconciled under skills/<category>/<name> before startup.
        Use a sops-nix secret to keep contents out of the Nix store.
        See docs/hermes-skills.md for the schema and SOPS configuration.
      '';
    };

    mcp = {
      nextcloud = {
        enable = lib.mkEnableOption "the remote Nextcloud Context Agent MCP connection";
        url = lib.mkOption {
          type = lib.types.str;
          default = "https://${config.homelab.services.nextcloud.url}/index.php/apps/app_api/proxy/context_agent/mcp/";
          description = "Shared Context Agent endpoint; NEXTCLOUD_APP_PASSWORD is resolved from each Hermes profile's runtime environment.";
        };
      };
      garmin = {
        enable = lib.mkEnableOption "Garmin Connect MCP";
        tokensFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = lib.literalExpression ''config.sops.secrets."hermes/garmin-tokens".path'';
          description = ''
            Absolute runtime path to a secret containing garmin_tokens.json.
            Copied into the writable Garmin token directory before startup.
            Use sops-nix to keep tokens out of the Nix store. Each startup
            restores this secret; publish renewed tokens to SOPS when needed.
          '';
        };
        revision = lib.mkOption {
          type = lib.types.str;
          default = "202913fde53c9d15890d661fc9748dc6d0d5af52";
          description = "Taxuspt/garmin_mcp Git revision used for both MCP and interactive authentication.";
        };
      };
    };

    providersFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = lib.literalExpression ''config.sops.secrets."hermes/providers".path'';
      description = ''
        Absolute runtime path to a private JSON list of providers and credentials.
        Supports openai-codex, opencode-go and zai. The first entry selects the
        default provider and model. Reconciled before gateway/backend startup;
        also reconciled after activation installs config.yaml, even when the
        services remain running, so configFile cannot erase the global model.
        Codex token refreshes survive restarts until the declared tokens change.
        See docs/hermes-providers.md for the schema and SOPS configuration.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Generic Hermes Agent settings passed to the upstream module";
    };

    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Runtime path to a complete Hermes config.yaml. When set, this replaces
        settings; use a SOPS secret path for private configuration. Nix MCP
        definitions are merged into the runtime file after activation and
        before native service startup, replacing entries with the same names.
      '';
      example = lib.literalExpression ''config.sops.secrets."hermes/config-file".path'';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !mergeMcpConfig || !config.services.hermes-agent.container.enable;
        message = "Combining configFile with Nix MCP definitions requires native service mode";
      }
      {
        assertion = cfg.providersFile == null || lib.hasPrefix "/" cfg.providersFile;
        message = "homelab.services.hermes-agent.providersFile must be an absolute runtime path";
      }
      {
        assertion = cfg.providersFile == null || !config.services.hermes-agent.container.enable;
        message = "homelab.services.hermes-agent.providersFile requires native service mode";
      }
      {
        assertion = cfg.providersFile == null || !(lib.any (key: builtins.hasAttr key (cfg.settings.model or { }))
          [ "provider" "default" "base_url" "api_key" "key_env" "api_mode" ]);
        message = "With providersFile, declare model routing in hermes/providers, not settings.model";
      }
      {
        assertion = cfg.providersFile == null || config.services.hermes-agent.authFile == null;
        message = "providersFile manages authentication and cannot be combined with services.hermes-agent.authFile";
      }
      {
        assertion = cfg.environmentFile != null;
        message = "homelab.services.hermes.environmentFile must be set when Hermes is enabled";
      }
      {
        assertion = cfg.cronJobsFile == null || lib.hasPrefix "/" cfg.cronJobsFile;
        message = "homelab.services.hermes-agent.cronJobsFile must be an absolute runtime path";
      }
      {
        assertion = cfg.cronJobsFile == null || !config.services.hermes-agent.container.enable;
        message = "homelab.services.hermes-agent.cronJobsFile requires native service mode";
      }
      {
        assertion = cfg.skillsFile == null || lib.hasPrefix "/" cfg.skillsFile;
        message = "homelab.services.hermes-agent.skillsFile must be an absolute runtime path";
      }
      {
        assertion = cfg.skillsFile == null || !config.services.hermes-agent.container.enable;
        message = "homelab.services.hermes-agent.skillsFile requires native service mode";
      }
      {
        assertion = !cfg.mcp.garmin.enable || !config.services.hermes-agent.container.enable;
        message = "homelab.services.hermes-agent.mcp integrations require native service mode";
      }
      {
        assertion = cfg.mcp.garmin.tokensFile == null || lib.hasPrefix "/" cfg.mcp.garmin.tokensFile;
        message = "homelab.services.hermes-agent.mcp.garmin.tokensFile must be an absolute runtime path";
      }
    ];

    # See options in: https://github.com/NousResearch/hermes-agent/blob/main/nix/nixosModules.nix
    services.hermes-agent = {
      enable = true;
      inherit (cfg) addToSystemPackages backend configFile package stateDir settings;
      environmentFiles = [ cfg.environmentFile ];
      extraPackages = lib.optionals cfg.mcp.garmin.enable [ pkgs.uv pkgs.python312 ];
      mcpServers = lib.optionalAttrs cfg.mcp.nextcloud.enable
        {
          nextcloud = {
            inherit (cfg.mcp.nextcloud) url;
            headers.Authorization = "Bearer \${NEXTCLOUD_APP_PASSWORD}";
          };
        } // lib.optionalAttrs cfg.mcp.garmin.enable {
        garmin = {
          command = "${pkgs.uv}/bin/uvx";
          args = garminArgs ++ [ "garmin-mcp" ];
          connect_timeout = 180;
          env.GARMINTOKENS = "${cfg.stateDir}/.garminconnect";
        };
      };
    };

    environment.systemPackages = lib.optionals cfg.mcp.garmin.enable [ garminAuth ];

    system.activationScripts.hermes-agent-mcp = lib.mkIf mergeMcpConfig
      (lib.stringAfter [ "hermes-agent-setup" ] ''
        ${pkgs.util-linux}/bin/runuser -u ${lib.escapeShellArg config.services.hermes-agent.user} -- \
          ${pkgs.coreutils}/bin/env HERMES_HOME=${lib.escapeShellArg "${config.services.hermes-agent.stateDir}/.hermes"} \
          ${mergeMcp}
      '');

    # Upstream copies configFile on every activation. A service restart is not
    # guaranteed when the unit and secret contents are unchanged, so preStart
    # alone can leave a running gateway without its provider/model routing.
    system.activationScripts.hermes-agent-providers = lib.mkIf (cfg.providersFile != null)
      (lib.stringAfter [ "hermes-agent-setup" ] ''
        ${pkgs.util-linux}/bin/runuser -u ${lib.escapeShellArg config.services.hermes-agent.user} -- \
          ${pkgs.coreutils}/bin/env HERMES_HOME=${lib.escapeShellArg "${config.services.hermes-agent.stateDir}/.hermes"} \
          ${reconcileProviders}
      '');

    systemd.services = lib.mkMerge [
      (lib.mkIf mergeMcpConfig
        (lib.genAttrs ([ "hermes-agent" ] ++ lib.optionals (cfg.backend.mode != "none") [ "hermes-backend" ]) (_: {
          after = [ "sops-install-secrets.service" ];
          serviceConfig.UMask = lib.mkForce "0077";
          preStart = lib.mkBefore mergeMcp;
        })))
      (lib.mkIf (cfg.skillsFile != null)
        (lib.genAttrs ([ "hermes-agent" ] ++ lib.optionals (cfg.backend.mode != "none") [ "hermes-backend" ]) (_: {
          after = [ "sops-install-secrets.service" ];
          serviceConfig.UMask = lib.mkForce "0077";
          preStart = lib.mkBefore ''
            ${pkgs.python3}/bin/python3 \
              ${./reconcile-skills.py} ${lib.escapeShellArg cfg.skillsFile}
          '';
        })))
      (lib.mkIf (cfg.providersFile != null)
        (lib.genAttrs ([ "hermes-agent" ] ++ lib.optionals (cfg.backend.mode != "none") [ "hermes-backend" ]) (_: {
          after = [ "sops-install-secrets.service" ];
          serviceConfig.UMask = lib.mkForce "0077";
          preStart = lib.mkBefore reconcileProviders;
        })))
      (lib.mkIf (cfg.mcp.garmin.enable && cfg.mcp.garmin.tokensFile != null)
        (lib.genAttrs ([ "hermes-agent" ] ++ lib.optionals (cfg.backend.mode != "none") [ "hermes-backend" ]) (_: {
          after = [ "sops-install-secrets.service" ];
          preStart = lib.mkBefore garminTokenSetup;
        })))
      {
        hermes-agent = lib.mkIf (cfg.cronJobsFile != null) {
          after = [ "sops-install-secrets.service" ];
          serviceConfig.UMask = lib.mkForce "0077";
          preStart = lib.mkAfter ''
            ${config.services.hermes-agent.package.hermesVenv}/bin/python3 \
              ${./reconcile-cron-jobs.py} ${lib.escapeShellArg cfg.cronJobsFile}
          '';
        };
      }
    ];
  };
}
