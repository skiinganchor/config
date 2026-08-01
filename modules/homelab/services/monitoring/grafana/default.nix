{ config
, lib
, ...
}:
let
  service = "grafana";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "monitor.${homelab.baseDomain}";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Grafana";
    };
    secretKeyFile = lib.mkOption {
      type = lib.types.str;
      example = lib.literalExpression ''
        pkgs.writeText "key.txt" '''
          aff769ceaae66feee18ac9c277ced28df82e70a51866a54c4c971e01bbc45c19
        '''
      '';
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Platform for data analytics and monitoring";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "grafana.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Observability";
    };
  };
  config = lib.mkIf cfg.enable {
    services.grafana = {
      enable = true;
      provision = {
        enable = true;
      };
      settings = {
        security.secret_key = "$__file{${cfg.secretKeyFile}}";
        server = {
          http_addr = "127.0.0.1";
          http_port = 3000;
          domain = cfg.url;
        };
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
          proxyPass = "http://${config.services.grafana.settings.server.http_addr}:${toString config.services.grafana.settings.server.http_port}";
          proxyWebsockets = true; # Grafana Live
        };
        sslCertificate = "/var/lib/acme/${homelab.baseDomain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${homelab.baseDomain}/key.pem";
      };
    };
  };
}
