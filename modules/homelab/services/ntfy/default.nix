{ config, lib, ... }:
let
  service = "ntfy";
  cfg = config.homelab.services.${service};
  hl = config.homelab;
  port = 2586;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "ntfy.${hl.baseDomain}";
    };
    monitoredServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "ntfy-sh" ];
    };
  };
  config = lib.mkIf cfg.enable {
    services.ntfy-sh = {
      enable = true;
      settings = {
        base-url = "https://${cfg.url}";
        listen-http = "127.0.0.1:${toString port}";
      };
    };
    services.nginx.virtualHosts."${cfg.url}" = {
      forceSSL = true;
      enableACME = false;
      sslCertificate = "/var/lib/acme/${hl.baseDomain}/fullchain.pem";
      sslCertificateKey = "/var/lib/acme/${hl.baseDomain}/key.pem";
      extraConfig = ''
        add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
      '';
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString port}";
        extraConfig = ''
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
          proxy_read_timeout 3600;
          keepalive_timeout 3600;
        '';
      };
    };
  };
}
