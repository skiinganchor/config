{ config, sops-nix, ... }:
let
  domain = "tapirus.cc";
  mainUserName = "share";
  mainUserGroup = "users";
in
{
  imports = [
    sops-nix.nixosModules.sops
  ];

  sops.secrets."db-password" = {};
  sops.secrets."keycloak/db-password" = {
    key = "keycloak-db-password";
  };
  sops.secrets."nextcloud/db-password" = {
    key = "db-password";
    owner = "nextcloud";
    group = "nextcloud";
    mode = "0440";
  };
  sops.secrets."nextcloud/admin-password" = {};
  sops.secrets."nextcloud/secrets" = {};

  homelab = {
    baseDomain = domain;
    mainUser = {
      name = mainUserName;
      group = mainUserGroup;
      pkgs = [];
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
          options = [ "rw" "hard" "intr" "vers=4.1"];
          owner = mainUserName;
          group = mainUserGroup;
        };
        nextcloud = {
          remoteHost = "192.168.41.5";
          remotePath = "/ndata";
          localPath = "/mnt/nextcloud";
          fsType = "nfs";
          options = [ "rw" "hard" "intr" "vers=4.1"];
          owner = "nextcloud";
          group = "nextcloud";
        };
      };
    };
    services = {
      enable = true;
      audiobookshelf.enable = true;
      bazarr.enable = true;
      fail2ban.enable = true;
      homeassistant.enable = true;
      homepage.enable = true;
      immich.enable = false;
      jellyfin.enable = false;
      jellyseerr.enable = true;
      keycloak = {
        enable = true;
        dbPasswordFile = config.sops.secrets."keycloak/db-password".path;
        url = "friend.${domain}";
      };
      kvm.enable = true;
      lidarr.enable = true;
      mariadb.enable = true;
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
      sonarr.enable = true;
      vaultwarden.enable = false;
    };
    timeZone = "Europe/Amsterdam";
  };
}
