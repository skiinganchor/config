{ lib, ... }:
{
  options.homelab.services = {
    enable = lib.mkEnableOption "Settings and services for the homelab";
  };

  imports = [
    ./arr/prowlarr
    ./arr/bazarr
    ./arr/jellyseerr
    ./arr/lidarr
    ./arr/sonarr
    ./arr/radarr
    ./deluge
    ./jellyfin
    ./nextcloud
    ./sabnzbd
    ./wireguard-netns
  ];
}
