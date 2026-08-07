{ config
, lib
, pkgs
, ...
}:
let
  service = "grafana";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  keycloakUrl = config.homelab.services.keycloak.url;
  dashboardsDir = import ./dashboards.nix { inherit pkgs; };
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
    adminPasswordFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to the Grafana admin password file. The default admin/admin
        credentials are removed and replaced by the contents of this file.
      '';
    };
    oidcClientSecretFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to the Keycloak OIDC client secret. When null, generic OAuth is
        not configured and only the break-glass admin login is available.
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
        dashboards.settings.providers = [
          {
            name = "homelab";
            orgId = 1;
            folder = "Homelab";
            type = "file";
            disableDeletion = false;
            updateIntervalSeconds = 30;
            allowUiUpdates = false;
            options.path = dashboardsDir;
            options.foldersFromFilesStructure = false;
          }
        ];
      };
      settings = {
        security.secret_key = "$__file{${cfg.secretKeyFile}}";
        security.admin_password = "$__file{${cfg.adminPasswordFile}}";
        security.cookie_secure = true;
        users.allow_sign_up = false;
        auth.disable_login_form = false;
        server = {
          http_addr = "127.0.0.1";
          http_port = 3000;
          domain = cfg.url;
          root_url = "https://${cfg.url}/";
        };
      } // lib.optionalAttrs (cfg.oidcClientSecretFile != null) {
        "auth.generic_oauth" = {
          enabled = true;
          name = "Keycloak";
          icon = "signin";
          client_id = "grafana";
          client_secret = "$__file{${cfg.oidcClientSecretFile}}";
          scopes = "openid profile email";
          auth_url = "https://${keycloakUrl}/realms/sacred/protocol/openid-connect/auth";
          token_url = "https://${keycloakUrl}/realms/sacred/protocol/openid-connect/token";
          api_url = "https://${keycloakUrl}/realms/sacred/protocol/openid-connect/userinfo";
          allow_sign_up = true;
          auto_login = false;
          use_pkce = true;
          login_attribute_path = "preferred_username";
          role_attribute_path = "contains(realm_access.roles[*], 'grafana-admin') && 'Admin' || 'Viewer'";
          signout_redirect_url = "https://${keycloakUrl}/realms/sacred/protocol/openid-connect/logout?post_logout_redirect_uri=https%3A%2F%2F${cfg.url}&client_id=grafana";
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
