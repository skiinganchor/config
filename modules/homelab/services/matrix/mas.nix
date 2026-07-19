{ lib, config, ... }:
let
  cfg = config.homelab.services.matrix;
  mas = cfg.mas;
  hl = config.homelab;
in
{
  options.homelab.services.matrix.mas = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable Matrix Authentication Service (MAS) and configure Synapse to
        delegate authentication to it. This replaces Synapse's legacy
        oidc_providers integration and supports clients such as Element X.
      '';
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "matrix-auth.${hl.baseDomain}";
      description = "Public hostname for MAS (used as OAuth 2.0 issuer)";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8083; # 8080 is the default but is already in use
      description = "Local port MAS listens on (loopback only, nginx fronts TLS)";
    };
    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Path to the fully-rendered MAS configuration YAML (typically a sops
        secret). Must contain all secrets (encryption key, signing keys,
        matrix.secret, and upstream_oauth2 with the Keycloak provider).
        Generate a starting point with `mas-cli config generate`, then edit
        the URLs and add the Keycloak upstream provider.
      '';
    };
    sharedSecretFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Path to the shared secret used by Synapse and MAS to authenticate
        requests between the two services. Its contents must match
        matrix.secret in the MAS configuration.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && mas.enable) {
    assertions = [
      {
        assertion = mas.configFile != null;
        message = "homelab.services.matrix.mas.configFile must be set when MAS is enabled";
      }
      {
        assertion = mas.sharedSecretFile != null;
        message = "homelab.services.matrix.mas.sharedSecretFile must be set when MAS is enabled";
      }
      {
        assertion = cfg.oidcClientSecretFile == null;
        message = "homelab.services.matrix.oidcClientSecretFile cannot be used together with MAS. Delegated authentication disables Synapse's legacy OIDC path; configure Keycloak as an upstream provider in the MAS config instead.";
      }
    ];

    services.matrix-authentication-service = {
      enable = true;
      createDatabase = true;
      extraConfigFiles = [ mas.configFile ];
      # MAS additively merges lists from every config file. Keep this empty
      # while configFile is still a complete legacy configuration, otherwise
      # both listener sets try to bind the same address.
      settings.http.listeners = [ ];
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
