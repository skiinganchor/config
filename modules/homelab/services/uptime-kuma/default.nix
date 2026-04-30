{ config, lib, pkgs, ... }:
let
  service = "uptime-kuma";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/uptime-kuma";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "uptime.${homelab.baseDomain}";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Uptime Kuma";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Service monitoring tool";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "uptime-kuma.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Observability";
    };
    resolveReverseProxyLocally = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Resolve this host's nginx virtual hosts through loopback so local
        Uptime Kuma checks do not depend on the router DNS path.
      '';
    };
  };
  config = lib.mkIf cfg.enable {
    networking.hosts."127.0.0.1" = lib.optionals cfg.resolveReverseProxyLocally (
      builtins.attrNames config.services.nginx.virtualHosts
    );

    services.${service} = {
      enable = true;
      # currently needed for version 2 (current stable is version 1) - remove on upgrade
      package = pkgs.pkgs-unstable.uptime-kuma;
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
          proxyPass = "http://127.0.0.1:3001";
        };
        sslCertificate = "/var/lib/acme/${config.homelab.baseDomain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${config.homelab.baseDomain}/key.pem";
      };
    };
  };
}
