{ config, lib, ... }:
let
  wg = config.homelab.networks.local.wireguard-ext;
  wgBase = lib.strings.removeSuffix ".1" wg.cidr.v4;
in
{
  homelab = {
    opencode.useOpencodeGo = true;
    services = {
      enable = true;
      bazarr.enable = false;
      deluge.enable = false;
      fail2ban.enable = true;
      hermes-agent = {
        enable = false;
        addToSystemPackages = true;
        environmentFile = config.sops.secrets."hermes/env-file".path;
        settings.model.default = "opencode-go/qwen3.7-plus";
      };
      jellyfin.enable = true;
      seerr.enable = false;
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
