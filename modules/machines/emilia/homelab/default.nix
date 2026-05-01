{ config, lib, my-secrets, sops-nix, ... }:
let
  domain = "tapirus.cc";
  mainUserName = "share";
  mainUserGroup = "users";
  secretsPath = builtins.toString my-secrets;
  wg = config.homelab.networks.local.wireguard-ext;
  wgBase = lib.strings.removeSuffix ".1" wg.cidr.v4;
in
{
  imports = [
    sops-nix.nixosModules.sops
  ];

  sops.secrets."db-password" = { };
  sops.secrets."keycloak/db-password" = {
    key = "keycloak-db-password";
  };
  sops.secrets."navidrome/env-file" = { };
  sops.secrets."nextcloud/db-password" = {
    key = "db-password";
    owner = "nextcloud";
    group = "nextcloud";
    mode = "0440";
  };
  sops.secrets."nextcloud/admin-password" = { };
  sops.secrets."nextcloud/secrets" = { };
  sops.secrets."slskd/env-file" = { };
  sops.secrets."wireguard-netns/config" = {
    sopsFile = "${secretsPath}/secrets/shared.yaml";
  };

  homelab = {
    baseDomain = domain;
    mainUser = {
      name = mainUserName;
      group = mainUserGroup;
      pkgs = [ ];
    };
    networks.local.wireguard-ext = {
      id = 15;
      cidr = {
        v4 = "10.68.0.1";
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
      audiobookshelf.enable = true;
      bazarr.enable = true;
      deluge.enable = false;
      fail2ban.enable = true;
      homeassistant.enable = true;
      homepage.enable = true;
      immich.enable = false;
      jellyfin.enable = false;
      jellyseerr.enable = true;
      keycloak = {
        enable = true;
        dbPasswordFile = config.sops.secrets."keycloak/db-password".path;
      };
      kvm.enable = true;
      lidarr.enable = true;
      mariadb.enable = true;
      navidrome = {
        enable = false;
        environmentFile = config.sops.secrets."navidrome/env-file".path;
      };
      netboot-xyz.enable = false;
      nextcloud = {
        enable = true;
        adminUser = mainUserName;
        adminPassFile = config.sops.secrets."nextcloud/admin-password".path;
        dbUser = "ncadmin";
        dbPassFile = config.sops.secrets."db-password".path;
        ncDbPassFile = config.sops.secrets."nextcloud/db-password".path;
        secretsJsonFile = config.sops.secrets."nextcloud/secrets".path;
      };
      nginx.enable = true;
      paperless.enable = false;
      prowlarr.enable = true;
      radarr.enable = true;
      sabnzbd = {
        enable = true;
        host = "0.0.0.0";
      };
      slskd = {
        enable = true;
        environmentFile = config.sops.secrets."slskd/env-file".path;
      };
      sonarr.enable = true;
      uptime-kuma.enable = true;
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

  # Navidrome's upstream sandbox bind-mounts the music library into a private
  # root. That mount namespacing fails against this NFS-backed path on Emilia,
  # so disable only that confinement here and leave the shared module intact.
  systemd.services.navidrome.serviceConfig = {
    RootDirectory = lib.mkForce "";
    BindReadOnlyPaths = lib.mkForce [ ];
  };
}
