{ config
, lib
, pkgs
, ...
}:
let
  homelab = config.homelab;
  cfg = homelab.services.deluge;
  ns = homelab.services.wireguard-netns.namespace;
in
{
  options.homelab.services.deluge = {
    enable = lib.mkEnableOption "Deluge torrent client (bound to a Wireguard VPN network)";
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/deluge";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "deluge.${homelab.baseDomain}";
    };
    monitoredServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "delugeweb"
        "deluged-proxy"
        "deluged"
      ];
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Deluge";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Torrent client";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "deluge.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Downloads";
    };
  };
  config = lib.mkIf cfg.enable {
    services.deluge = {
      enable = true;
      user = homelab.mainUser.name;
      group = homelab.mainUser.group;
      web = {
        enable = true;
      };
    };

    services.nginx = {
      virtualHosts."${cfg.url}" = {
        forceSSL = true;
        # uses security.acme instead
        enableACME = false;
        extraConfig = ''
          # Add HSTS header to force HTTPS
          add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;

          # Add X-XSS-Protection header for additional XSS protection
          add_header X-XSS-Protection "1; mode=block" always;
        '';
        locations."/" = {
          proxyPass = "http://127.0.0.1:8112";
        };
        sslCertificate = "/var/lib/acme/${config.homelab.baseDomain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${config.homelab.baseDomain}/key.pem";
      };
    };

    systemd = lib.mkIf homelab.services.wireguard-netns.enable {
      services.deluged.bindsTo = [ "netns@${ns}.service" ];
      services.deluged.requires = [
        "network-online.target"
        "${ns}.service"
      ];
      services.deluged.serviceConfig.NetworkNamespacePath = [ "/var/run/netns/${ns}" ];
      sockets."deluged-proxy" = {
        enable = true;
        description = "Socket for Proxy to Deluge WebUI";
        listenStreams = [ "58846" ];
        wantedBy = [ "sockets.target" ];
      };
      services."deluged-proxy" = {
        enable = true;
        description = "Proxy to Deluge Daemon in Network Namespace";
        requires = [
          "deluged.service"
          "deluged-proxy.socket"
        ];
        after = [
          "deluged.service"
          "deluged-proxy.socket"
        ];
        unitConfig = {
          JoinsNamespaceOf = "deluged.service";
        };
        serviceConfig = {
          User = config.services.deluge.user;
          Group = config.services.deluge.group;
          ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=5min 127.0.0.1:58846";
          PrivateNetwork = "yes";
        };
      };
    };
  };
}
