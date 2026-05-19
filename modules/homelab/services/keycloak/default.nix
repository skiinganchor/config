{ config
, lib
, pkgs
, ...
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
      default = "friend.${homelab.baseDomain}";
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
    oauth2ProxyEnvFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression ''
        pkgs.writeText "oauth2proxy-envfile" '''
          OAUTH2_PROXY_CLIENT_SECRET=foobar
          OAUTH2_PROXY_COOKIE_SECRET=barfoo
        '''
      '';
    };
  };
  config = lib.mkIf cfg.enable {
    services.oauth2-proxy = lib.mkIf (cfg.oauth2ProxyEnvFile != null) {
      enable = true;
      keyFile = cfg.oauth2ProxyEnvFile;
      reverseProxy = true;
      provider = "keycloak-oidc";
      oidcIssuerUrl = "https://${cfg.url}/realms/sacred";
      cookie = {
        expire = "672h";
        refresh = "1h";
        secure = true;
        httpOnly = true;
        domain = lib.strings.removePrefix "friend" cfg.url;
      };
      httpAddress = "127.0.0.1:4192";
      clientID = "oauth2-proxy";
      upstream = [ "http://[::]:0/" ];
      scope = "openid profile email";
      email.domains = [ "*" ];
      extraConfig = {
        skip-provider-button = true;
        whitelist-domain = [ ("*" + (lib.strings.removePrefix "friend" cfg.url)) ];
        code-challenge-method = "S256";
      };
    };

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
