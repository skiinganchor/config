{ config, lib, ... }:
let
  wg = config.homelab.networks.local.wireguard-ext;
  wgBase = lib.strings.removeSuffix ".1" wg.cidr.v4;
in
{
  homelab = {
    services = {
      enable = true;
      bazarr.enable = false;
      deluge.enable = false;
      fail2ban.enable = true;
      jellyfin.enable = true;
      jellyseerr.enable = false;
      netboot-xyz.enable = false;
      nextcloud.enable = false;
      nginx.enable = true;
      prowlarr.enable = false;
      radarr.enable = false;
      sabnzbd.enable = false;
      sonarr.enable = false;
      stirling-pdf.enable = false;
      tftpd.enable = false;
      wireguard-netns = {
        enable = true;
        configFile = config.sops.secrets."wireguard-netns/config".path;
        privateIP = "${wgBase}.2";
        dnsIP = wg.cidr.v4;
      };
    };
  };
}
