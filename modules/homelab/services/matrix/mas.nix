{ lib, config, ... }:
let
  cfg = config.homelab.services.matrix;
  inherit (cfg) mas;
  hl = config.homelab;
  credentialPath = name: "\${CREDENTIALS_DIRECTORY}/${name}";
  signingKeyCredentials = lib.listToAttrs (
    lib.imap0 (i: path: lib.nameValuePair "signing-key-${toString i}" path) mas.signingKeyFiles
  );
in
{
  config = lib.mkIf (cfg.enable && mas.enable) {
    assertions = [
      {
        assertion = mas.encryptionSecretFile != null;
        message = "homelab.services.matrix.mas.encryptionSecretFile must be set when MAS is enabled";
      }
      {
        assertion = mas.signingKeyFiles != [ ];
        message = "homelab.services.matrix.mas.signingKeyFiles must contain at least one signing key when MAS is enabled";
      }
      {
        assertion = mas.sharedSecretFile != null;
        message = "homelab.services.matrix.mas.sharedSecretFile must be set when MAS is enabled";
      }
      {
        assertion = mas.upstreamOAuth2.clientSecretFile != null;
        message = "homelab.services.matrix.mas.upstreamOAuth2.clientSecretFile must be set when MAS is enabled";
      }
      {
        assertion = cfg.oidcClientSecretFile == null;
        message = "homelab.services.matrix.oidcClientSecretFile cannot be used together with MAS. Delegated authentication disables Synapse's legacy OIDC path; configure Keycloak as an upstream provider in the MAS config instead.";
      }
    ];

    services.matrix-authentication-service = {
      enable = true;
      createDatabase = true;
      credentials = {
        encryption = mas.encryptionSecretFile;
        synapse-shared-secret = mas.sharedSecretFile;
        upstream-oauth2-client-secret = mas.upstreamOAuth2.clientSecretFile;
      } // signingKeyCredentials;
      settings = {
        http = {
          public_base = "https://${mas.url}/";
          issuer = "https://${mas.url}/";
          listeners = [
            {
              name = "web";
              resources = map (name: { inherit name; }) [
                "discovery"
                "human"
                "oauth"
                "compat"
                "graphql"
                "assets"
              ];
              binds = [
                {
                  host = "127.0.0.1";
                  inherit (mas) port;
                }
              ];
              proxy_protocol = false;
            }
          ];
        };
        database = {
          uri = "postgresql:///matrix-authentication-service?host=/run/postgresql";
          max_connections = 10;
          min_connections = 0;
          connect_timeout = 30;
          idle_timeout = 600;
          max_lifetime = 1800;
        };
        email = {
          from = ''"Authentication Service" <root@localhost>'';
          reply_to = ''"Authentication Service" <root@localhost>'';
          transport = "blackhole";
        };
        secrets = {
          encryption_file = credentialPath "encryption";
          keys = lib.imap0
            (i: _: {
              key_file = credentialPath "signing-key-${toString i}";
            })
            mas.signingKeyFiles;
        };
        passwords = {
          enabled = false;
          minimum_complexity = 3;
        };
        matrix = {
          kind = "synapse";
          homeserver = cfg.url;
          secret_file = credentialPath "synapse-shared-secret";
          endpoint = "http://[::1]:8008/";
        };
        upstream_oauth2.providers = [
          {
            id = mas.upstreamOAuth2.providerId;
            issuer = "https://${hl.services.keycloak.url}/realms/sacred";
            client_id = mas.upstreamOAuth2.clientId;
            client_secret_file = credentialPath "upstream-oauth2-client-secret";
            id_token_signed_response_alg = "ES256";
            pkce_method = "always";
            token_endpoint_auth_method = "client_secret_post";
            scope = "openid profile email";
            claims_imports = {
              skip_confirmation = true;
              localpart = {
                action = "require";
                template = "{{ user.preferred_username }}";
              };
              displayname = {
                action = "force";
                template = "{{ user.name }}";
              };
              email = {
                action = "force";
                template = "{{ user.email }}";
                set_email_verification = "import";
              };
            };
          }
        ];
      };
    };

    services.nginx.virtualHosts."${mas.url}" = {
      forceSSL = true;
      enableACME = false;
      extraConfig = ''
        add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
      '';
      sslCertificate = "/var/lib/acme/${hl.baseDomain}/fullchain.pem";
      sslCertificateKey = "/var/lib/acme/${hl.baseDomain}/key.pem";
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString mas.port}";
        extraConfig = ''
          proxy_http_version 1.1;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        '';
      };
    };

    services.nginx.virtualHosts."${cfg.url}".locations."~ ^/_matrix/client/(.*)/(login|logout|refresh)" = {
      proxyPass = "http://127.0.0.1:${toString mas.port}";
      extraConfig = ''
        proxy_http_version 1.1;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      '';
    };

    homelab.services.matrix.monitoredServices = [ "matrix-synapse" "matrix-authentication-service" ];

    services.matrix-synapse.settings.matrix_authentication_service = {
      enabled = true;
      endpoint = "http://127.0.0.1:${toString mas.port}/";
      secret_path = mas.sharedSecretFile;
    };
  };
}
