{ config, my-secrets, sops-nix, ... }:
let
  secretsPath = builtins.toString my-secrets;
in
{
  imports = [
    sops-nix.nixosModules.sops
  ];

  sops.defaultSopsFile = "${secretsPath}/secrets/services.yaml";
  sops.age.keyFile = "/home/share/.config/sops/age/keys.txt";
  sops.secrets.nextcloud-adminuser = {};
  sops.secrets.nextcloud-adminPassword = {};

  homelab = {
    mainUser = {
      name = "share";
      group = "users";
      pkgs = [];
    };
    services = {
      enable = true;
      nextcloud = {
        enable = true;
        adminuser = config.sops.secrets.nextcloud-adminuser.path;
        adminpassFile = config.sops.secrets.nextcloud-adminPassword.path;
      };
    };
    timeZone = "Europe/Amsterdam";
  };
}
