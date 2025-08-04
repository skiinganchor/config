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
    services = {
      enable = true;
      nextcloud = {
        enable = true;
        adminuser = "share";
        adminpassFile = config.sops.secrets."nextcloud-admin-password".path;
      };
    };
    timeZone = "Europe/Amsterdam";
  };
}
