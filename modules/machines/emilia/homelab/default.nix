{ config, lib, my-secrets, pkgs, sops-nix, ... }:
let
  domain = "tapirus.cc";
  mainUserName = "share";
  mainUserGroup = "users";
  secretsPath = builtins.toString my-secrets;
  wg = config.homelab.networks.local.wireguard-ext;
  wgBase = lib.strings.removeSuffix ".1" wg.cidr.v4;
  aurralLandlock = pkgs.writeShellScript "aurral-landlock" ''
    landrunArgs=(
      --unrestricted-network
      --rox ${lib.escapeShellArg builtins.storeDir}
      --ro /mnt/media/music
      --ro /mnt/media/music/library
      --rw /mnt/media/music/aurral
      --rw /mnt/media/music/import
      --rw /var/lib/aurral
      --rw /tmp
      --rw /dev/null
      --ro /dev/urandom
      --ro /proc
      --ro /etc/hosts
      --ro /etc/resolv.conf
      --ro /etc/nsswitch.conf
      --ro /etc/passwd
      --ro /etc/group
      --ro /etc/ssl/certs/ca-certificates.crt
    )
    if [[ -e /etc/localtime ]]; then
      landrunArgs+=(--ro /etc/localtime)
    fi
    if [[ -n ''${CREDENTIALS_DIRECTORY:-} ]]; then
      landrunArgs+=(--ro "$CREDENTIALS_DIRECTORY")
    fi
    # landrun requires explicit environment passthrough. Pass names only so
    # values supplied by systemd never appear in command-line arguments.
    while IFS= read -r -d "" entry; do
      name="''${entry%%=*}"
      [[ "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
      landrunArgs+=(--env "$name")
    done < <(${lib.getExe' pkgs.coreutils "env"} -0)

    exec ${lib.getExe pkgs.landrun} "''${landrunArgs[@]}" -- "$@"
  '';
in
{
  imports = [
    sops-nix.nixosModules.sops
  ];

  # Reserve the NFS identity for the account created by services.aurral.
  users.users.aurral.uid = 1201;
  users.groups.aurral.gid = 1201;

  # The NFS server manages the curated library and its ACLs.
  systemd.tmpfiles.settings.navidromeDirs.${config.homelab.services.navidrome.musicDir} = lib.mkForce { };

  sops = {
    secrets = {
      "alertson-ip" = { };
      "db-password" = { };
      "fail2ban/ignoreip" = {
        owner = "root";
        mode = "0400";
        restartUnits = [ "fail2ban.service" ];
      };
      "homepage/env-file" = {
        restartUnits = [ "homepage-dashboard.service" ];
      };
      "keycloak/db-password" = { };
      "keycloak/oauth2-proxy-env-file" = { };
      "matrix/mas/encryption" = { };
      "matrix/mas/signing-key-ec-1" = { };
      "matrix/mas/signing-key-ec-2" = { };
      "matrix/mas/signing-key-ec-3" = { };
      "matrix/mas/signing-key-rsa" = { };
      "matrix/mas/synapse-shared-secret" = {
        owner = "matrix-synapse";
      };
      "matrix/oidc-client-secret" = { };
      "matrix/registration-secret" = {
        owner = "matrix-synapse";
      };
      "navidrome/env-file" = { };
      "nextcloud/admin-password" = { };
      "nextcloud/db-password" = {
        key = "db-password";
        owner = "nextcloud";
        group = "nextcloud";
        mode = "0440";
      };
      "nextcloud/secrets" = { };
      "ntfy/env-file" = { };
      "slskd/env-file" = { };
      "stirling-pdf/env-file" = {
        restartUnits = [ "stirling-pdf.service" ];
      };
      "wireguard-netns/config" = {
        sopsFile = "${secretsPath}/secrets/shared.yaml";
      };
    };
    templates = {
      "grafana-upstream.conf" = {
        owner = "root";
        group = config.services.nginx.group;
        mode = "0440";
        reloadUnits = [ "nginx.service" ];
        content = ''
          upstream grafana_backend {
            server ${config.sops.placeholder."alertson-ip"}:3000;
          }
        '';
      };
      "slskd-health-allow.conf" = {
        owner = "root";
        group = config.services.nginx.group;
        mode = "0440";
        reloadUnits = [ "nginx.service" ];
        content = ''
          allow ${config.sops.placeholder."alertson-ip"};
        '';
      };
    };
  };

  systemd.services = {
    aurral = lib.mkIf config.services.aurral.enable {
      # slskd creates the completed-download directory in its pre-start hook.
      after = lib.optionals config.services.slskd.enable [ "slskd.service" ];
      unitConfig.RequiresMountsFor = [ "/mnt/media/music/library" "/mnt/media/music/import" ];
      serviceConfig = {
        # landrun execs the upstream command, keeping catatonit as PID 1.
        ExecStart = lib.mkForce "${aurralLandlock} ${lib.getExe pkgs.catatonit} -- ${lib.getExe config.services.aurral.package}";
        SupplementaryGroups = [ "users" ];
        PrivateTmp = true;
      };
    };
    # Otherwise setupSecrets installs the template during activation, before
    # services start. Keep the same ordering if systemd activation is enabled.
    nginx = {
      requires = lib.optionals config.sops.useSystemdActivation [ "sops-install-secrets.service" ];
      after = lib.optionals config.sops.useSystemdActivation [ "sops-install-secrets.service" ];
    };
    slskd.restartTriggers = [ config.sops.secrets."wireguard-netns/config".sopsFileHash ];
    wg_client.restartTriggers = [ config.sops.secrets."wireguard-netns/config".sopsFileHash ];
  };

  homelab = {
    baseDomain = domain;
    firewallLogging = false;
    mainUser = {
      name = mainUserName;
      group = mainUserGroup;
      pkgs = [ ];
    };
    networks.local.wireguard-ext = {
      id = 15;
      cidr = {
        v4 = "10.2.0.1";
        v6 = null;
      };
      dhcp = {
        v4 = false;
        v6 = false;
      };
    };
    nfs_client = {
      enable = true;
      mounts = {
        # rw makes it not readonly
        # hard and intr are often helpful for better behavior during network issues
        media = {
          remoteHost = "192.168.41.5";
          remotePath = "/media";
          localPath = "/mnt/media";
          fsType = "nfs";
          options = [ "rw" "hard" "intr" "vers=4.1" ];
          owner = mainUserName;
          group = mainUserGroup;
        };
        nextcloud = {
          remoteHost = "192.168.41.5";
          remotePath = "/ndata";
          localPath = "/mnt/nextcloud";
          fsType = "nfs";
          options = [ "rw" "hard" "intr" "vers=4.1" ];
          owner = "nextcloud";
          group = "nextcloud";
        };
      };
    };
    services = {
      enable = true;
      audiobookshelf.enable = false;
      aurral = {
        enable = true;
        openFirewall = true;
      };
      bazarr.enable = true;
      deluge.enable = false;
      fail2ban.enable = true;
      hermes-agent = {
        enable = true;
        addToSystemPackages = true;
        profilesFile = "${secretsPath}/secrets/hermes-emilia.yaml";
        backend = {
          mode = "dashboard";
          host = "0.0.0.0";
          port = 9119;
        };
        garmin.enable = true;
      };
      homeassistant.enable = true;
      homepage = {
        enable = true;
        environmentFile = config.sops.secrets."homepage/env-file".path;
      };
      immich.enable = false;
      jellyfin.enable = false;
      keycloak = {
        enable = true;
        dbPasswordFile = config.sops.secrets."keycloak/db-password".path;
        oauth2ProxyEnvFile = config.sops.secrets."keycloak/oauth2-proxy-env-file".path;
      };
      kvm.enable = true;
      lidarr.enable = true;
      mariadb.enable = true;
      matrix = {
        enable = true;
        calls.enable = false;
        registrationSecretFile = config.sops.secrets."matrix/registration-secret".path;
        # ntfy (UnifiedPush gateway) is resolved via /etc/hosts (the
        # uptime-kuma module maps every vhost to 127.0.0.1) before DNS is
        # consulted, so Synapse reaches it on loopback — but its default
        # ip_range_blacklist drops 127.0.0.0/8. Whitelist the loopback the
        # push actually targets; the LAN IP covers the path if /etc/hosts
        # ever stops shadowing it.
        ipRangeWhitelist = [ "127.0.0.1" "192.168.31.21" ];
        mas = {
          enable = true;
          encryptionSecretFile = config.sops.secrets."matrix/mas/encryption".path;
          signingKeyFiles = map (name: config.sops.secrets."matrix/mas/${name}".path) [
            "signing-key-rsa"
            "signing-key-ec-1"
            "signing-key-ec-2"
            "signing-key-ec-3"
          ];
          sharedSecretFile = config.sops.secrets."matrix/mas/synapse-shared-secret".path;
          upstreamOAuth2 = {
            providerId = "01KT73JSNJTTJ5MDCAEJ7NX2A2";
            clientId = "matrix-auth";
            clientSecretFile = config.sops.secrets."matrix/oidc-client-secret".path;
          };
        };
      };
      navidrome = {
        enable = true;
        environmentFile = config.sops.secrets."navidrome/env-file".path;
      };
      netboot-xyz.enable = false;
      nextcloud = {
        enable = true;
        contextAgent.enable = true;
        adminUser = mainUserName;
        adminPassFile = config.sops.secrets."nextcloud/admin-password".path;
        dbUser = "ncadmin";
        dbPassFile = config.sops.secrets."db-password".path;
        ncDbPassFile = config.sops.secrets."nextcloud/db-password".path;
        secretsJsonFile = config.sops.secrets."nextcloud/secrets".path;
      };
      grafana.proxy = {
        enable = true;
        upstream = "http://grafana_backend";
        upstream-config-file = config.sops.templates."grafana-upstream.conf".path;
      };
      nginx.enable = true;
      ntfy = {
        enable = true;
        environmentFile = config.sops.secrets."ntfy/env-file".path;
      };
      paperless.enable = false;
      prowlarr.enable = true;
      radarr.enable = true;
      sabnzbd = {
        enable = true;
        host = "0.0.0.0";
      };
      seerr.enable = true;
      slskd = {
        enable = true;
        healthCheckAllowFile = config.sops.templates."slskd-health-allow.conf".path;
        environmentFile = config.sops.secrets."slskd/env-file".path;
      };
      sonarr.enable = true;
      stirling-pdf = {
        enable = true;
        environmentFile = config.sops.secrets."stirling-pdf/env-file".path;
      };
      uptime-kuma.enable = false;
      vaultwarden.enable = false;
      wireguard-netns = {
        enable = true;
        configFile = config.sops.secrets."wireguard-netns/config".path;
        privateIP = "${wgBase}.2";
        dnsIP = wg.cidr.v4;
      };
    };
    timeZone = "Europe/Amsterdam";
  };

  services.fail2ban.jails.INCLUDES.settings = {
    before = "paths-nixos.conf";
    after = config.sops.secrets."fail2ban/ignoreip".path;
  };
}
