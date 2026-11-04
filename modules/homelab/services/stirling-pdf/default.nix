{ config, lib, pkgs, ... }:
let
  service = "stirling-pdf";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption service;
    url = lib.mkOption {
      type = lib.types.str;
      default = "pdf.${homelab.baseDomain}";
    };
    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = "Environment file containing the Stirling PDF Keycloak client secret and initial admin credentials.";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Stirling PDF";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "PDF editing platform";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "stirling-pdf.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Media";
    };
  };
  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      # TODO: remove unstable when changing to 26.11
      package = pkgs.pkgs-unstable.stirling-pdf;
      environment = {
        SERVER_PORT = 8888;
        SERVER_ADDRESS = "127.0.0.1";
        SERVER_FORWARDHEADERSSTRATEGY = "framework";
        SECURITY_ENABLELOGIN = true;
        SECURITY_LOGINMETHOD = "all";
        SECURITY_OAUTH2_ENABLED = true;
        SECURITY_OAUTH2_AUTOCREATEUSER = true;
        SECURITY_OAUTH2_BLOCKREGISTRATION = false;
        SECURITY_OAUTH2_CLIENT_KEYCLOAK_ISSUER = "https://${homelab.services.keycloak.url}/realms/sacred";
        SECURITY_OAUTH2_CLIENT_KEYCLOAK_CLIENTID = "stirling-pdf";
        SECURITY_OAUTH2_CLIENT_KEYCLOAK_SCOPES = "openid, profile, email";
        SECURITY_OAUTH2_CLIENT_KEYCLOAK_USEASUSERNAME = "preferred_username";
      };
      environmentFiles = [ cfg.environmentFile ];
    };

    services.nginx = {
      virtualHosts."${cfg.url}" = {
        forceSSL = true;
        # uses security.acme instead
        enableACME = false;
        extraConfig = ''
          # Extra upload limit for large PDFs
          client_max_body_size 250m;

          # Add HSTS header to force HTTPS
          add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;

          # Add X-XSS-Protection header for additional XSS protection
          add_header X-XSS-Protection "1; mode=block" always;
        '';
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:8888";
            extraConfig = ''
              proxy_set_header X-Forwarded-Port 443;
              # Add HSTS header to force HTTPS
              add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;

              # Add X-XSS-Protection header for additional XSS protection
              add_header X-XSS-Protection "1; mode=block" always;

              # Large PDFs can take minutes to process server-side
              proxy_connect_timeout 600s;
              proxy_send_timeout    600s;
              proxy_read_timeout    600s;
            '';
          };
        };
        sslCertificate = "/var/lib/acme/${config.homelab.baseDomain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${config.homelab.baseDomain}/key.pem";
      };
    };
  };
}
