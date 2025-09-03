{ config, sops-nix, ... }:
{
  imports = [
    sops-nix.nixosModules.sops
  ];

  sops.secrets."db-password" = {};
  sops.secrets."nextcloud/db-password" = {
    key = "db-password";
    owner = "nextcloud";
    group = "nextcloud";
    mode = "0440";
  };
  sops.secrets."nextcloud/admin-password" = {};
  sops.secrets."nextcloud/secrets" = {};

  homelab = {
    baseDomain = "tapirus.cc";
    mainUser = {
      name = "share";
      group = "users";
      pkgs = [];
    };
    nfs_client = {
      enable = true;
      mounts = {
        media = {
          remoteHost = "192.168.41.5";
          remotePath = "/ndata";
          localPath = "/mnt/nextcloud";
          fsType = "nfs";
          options = [ "rw" "hard" "intr" "vers=4.1"];
        };
      };
    };
    services = {
      enable = true;
      netboot-xyz.enable = true;
      nextcloud = {
        enable = true;
        adminUser = "share";
        adminPassFile = config.sops.secrets."nextcloud/admin-password".path;
        dbUser = "ncadmin";
        dbPassFile = config.sops.secrets."db-password".path;
        ncDbPassFile = config.sops.secrets."nextcloud/db-password".path;
        secretsJsonFile = config.sops.secrets."nextcloud/secrets".path;
      };
    };
    timeZone = "Europe/Amsterdam";
  };
}
