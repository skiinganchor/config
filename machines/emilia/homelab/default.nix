{ config, sops-nix, ... }:
{
  imports = [
    sops-nix.nixosModules.sops
  ];

  sops.secrets."nextcloud-admin-password" = {};

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
          localPath = "/mnt/ndata";
          fsType = "nfs";
          options = [ "rw" "hard" "intr" "vers=4.1"];
        };
      };
    };
    services = {
      enable = true;
      nextcloud = {
        enable = true;
        adminuser = "share";
        adminpassFile = config.sops.secrets."nextcloud-admin-password".path;
        extraApps = {
          inherit (config.services.nextcloud.package.packages.apps) news contacts calendar tasks;
        };
        extraAppsEnable = true;
      };
    };
    timeZone = "Europe/Amsterdam";
  };
}
