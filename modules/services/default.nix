{ config, lib, my-secrets, sops-nix, ... }:
let
  secretsPath = builtins.toString my-secrets;
  homelab = config.homelab;
in
{
  imports = [
    sops-nix.nixosModules.sops
    ./arr/prowlarr
    ./arr/bazarr
    ./arr/jellyseerr
    ./arr/lidarr
    ./arr/sonarr
    ./arr/radarr
    ./jellyfin
    ./nextcloud
    ./sabnzbd
    ./wireguard-netns
  ];

  options.homelab.services = {
    enable = lib.mkEnableOption "Settings and services for the homelab";
  };

  config = lib.mkIf (config.homelab.services.enable && homelab.baseDomain != "" ) {
    services.nginx = {
      enable = true;
      virtualHosts = {
        "http://${homelab.baseDomain}" = {
          extraConfig = ''
            redir https://{host}{uri}
          '';
        };
        "http://*.${homelab.baseDomain}" = {
          extraConfig = ''
            redir https://{host}{uri}
          '';
        };
      };
    };
  };
}
