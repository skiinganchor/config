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
      hermes-agent = {
        enable = true;
        addToSystemPackages = true;
        environmentFile = config.sops.secrets."hermes/env-file".path;
        # Select either configurations based on using opencode-go or openai-codex (needs manual auth) as main provider
        # settings.model.default = "opencode-go/qwen3.7-plus";
        settings.model = {
          provider = "openai-codex";
          default = "gpt-5.6-luna";
        };
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
