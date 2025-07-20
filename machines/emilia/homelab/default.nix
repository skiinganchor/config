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
  sops.secrets."nextcloud/admin-user" = {};
  sops.secrets."nextcloud/admin-password" = {};

  homelab = {
    baseDomain = "alavanca.duckdns.org";
    mainUser = {
      name = "share";
      group = "users";
      pkgs = [];
    };
    services = {
      enable = true;
      nextcloud = {
        enable = true;
        adminuser = config.sops.secrets."nextcloud/admin-user".path;
        adminpassFile = config.sops.secrets."nextcloud/admin-password".path;
      };
    };
    timeZone = "Europe/Amsterdam";
  };
}
