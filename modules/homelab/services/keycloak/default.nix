{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "keycloak";
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
      default = "login.${homelab.baseDomain}";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Keycloak";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Open Source Identity and Access Management";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "keycloak.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };
    dbPasswordFile = lib.mkOption {
      type = lib.types.path;
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.keycloak
      pkgs.custom_keycloak_themes.custom
    ];
    nixpkgs.overlays = [
      (_final: _prev: {
        custom_keycloak_themes = {
          custom = pkgs.callPackage ./theme.nix { };
        };
      })
    ];

    services.${service} = {
      enable = true;
      database.type = "mariadb";
      database.passwordFile = cfg.dbPasswordFile;
      initialAdminPassword = "dont.trust123defaults";
      settings = {
        spi-theme-static-max-age = "-1";
        spi-theme-cache-themes = false;
        spi-theme-cache-templates = false;
        http-port = 8821;
        hostname = cfg.url;
        hostname-strict = false;
        hostname-strict-https = false;
        proxy-headers = "xforwarded";
        http-enabled = true;
      };
      themes = {
        custom = pkgs.custom_keycloak_themes.custom;
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
          proxyPass = "http://127.0.0.1:${toString config.services.${service}.settings.http-port}";
        };
        sslCertificate = "/var/lib/acme/${config.homelab.baseDomain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${config.homelab.baseDomain}/key.pem";
      };
    };
  };
}
