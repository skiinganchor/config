{ config, lib, pkgs, ... }:
let
  service = "stirling-pdf";
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
      default = "pdf.${homelab.baseDomain}";
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
      # The React Automate (pipeline) runner hard-codes a 300000ms axios
      # timeout per step in frontend/src/core/constants/automation.ts; large
      # PDFs blow past it on Compress. Not configurable via env var — the
      # value is baked into the JS bundle, so bump it at build time.
      package = pkgs.stirling-pdf.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace frontend/src/core/constants/automation.ts \
            --replace-fail 'OPERATION_TIMEOUT: 300000,' 'OPERATION_TIMEOUT: 1800000,'
        '';
      });
      environment = {
        SERVER_PORT = 8888;
      };
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
            # proxyPass attribute (not inline proxy_pass) so NixOS auto-includes
            # recommendedProxyConfig — otherwise the proxy_set_header below would
            # suppress the inherited Host/X-Forwarded-* headers.
            proxyPass = "http://127.0.0.1:8888";
            extraConfig = ''
              auth_request /oauth2/auth;
              error_page 401 = /oauth2/sign_in;
              auth_request_set $user  $upstream_http_x_auth_request_user;
              auth_request_set $email $upstream_http_x_auth_request_email;
              proxy_set_header X-User  $user;
              proxy_set_header X-Email $email;
              auth_request_set $auth_cookie $upstream_http_set_cookie;
              add_header Set-Cookie $auth_cookie;
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
          "/oauth2/" = {
            proxyPass = "http://127.0.0.1:4192";
            extraConfig = ''
              proxy_set_header X-Auth-Request-Redirect $request_uri;
              # Increase size of nginx buffer size to send more roles
              # TODO: find a more efficient solution for checking roles
              proxy_buffer_size 16k;
              proxy_buffers 4 32k;
              proxy_busy_buffers_size 32k;
            '';
          };
          "= /oauth2/auth" = {
            proxyPass = "http://127.0.0.1:4192";
            extraConfig = ''
              proxy_set_header Content-Length "";
              proxy_pass_request_body off;
            '';
          };
        };
        sslCertificate = "/var/lib/acme/${config.homelab.baseDomain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${config.homelab.baseDomain}/key.pem";
      };
    };
  };
}
