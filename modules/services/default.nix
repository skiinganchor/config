{ config, lib, my-secrets, sops-nix, ... }:
let
  secretsPath = builtins.toString my-secrets;
  homelab = config.homelab;
in
{
  imports = [
    sops-nix.nixosModules.sops
    ./arr/bazarr
    ./arr/jellyseerr
    ./arr/lidarr
    ./arr/prowlarr
    ./arr/radarr
    ./arr/sonarr
    ./audiobookshelf
    ./fail2ban
    ./homeassistant
    ./homepage
    ./jellyfin
    ./keycloak
    ./mariadb
    ./netboot-xyz
    ./nextcloud
    ./nfs
    ./nginx
    ./paperless-ngx
    ./sabnzbd
    ./tftpd
    ./wireguard-netns
  ];

  options.homelab.services = {
    enable = lib.mkEnableOption "Settings and services for the homelab";
  };

  config = lib.mkIf (config.homelab.services.enable && homelab.baseDomain != "" ) {
    services.nginx = {
      enable = true;
    };
  };
}
