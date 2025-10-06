{ config, lib, ... }:
let
  homelab = config.homelab;
  cfg = config.homelab.services.kvm;
in
{
  options.homelab.services.kvm = {
    enable = lib.mkEnableOption {
      description = "Enable KVM";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "kvm.${homelab.baseDomain}";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "KVM";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Keyboard, video, and mouse control";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "jetkvm.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };
  };
  config = lib.mkIf cfg.enable {
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
          proxyPass = "http://192.168.31.42:80";
          extraConfig = ''
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $http_connection;
          '';
        };
        sslCertificate = "/var/lib/acme/${config.homelab.baseDomain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${config.homelab.baseDomain}/key.pem";
      };
    };
  };
}
