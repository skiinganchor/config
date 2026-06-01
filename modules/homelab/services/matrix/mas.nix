{ pkgs, lib, config, ... }:
let
  cfg = config.homelab.services.matrix;
  mas = cfg.mas;
  hl = config.homelab;
  masUser = "matrix-authentication-service";
in
{
  options.homelab.services.matrix.mas = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable Matrix Authentication Service (MAS) for MSC3861 OAuth 2.0
        authentication. Required for clients like Element X. When enabled,
        Synapse delegates all authentication to MAS, replacing the legacy
        oidc_providers integration.
      '';
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "matrix-auth.${hl.baseDomain}";
      description = "Public hostname for MAS (used as OAuth 2.0 issuer)";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Local port MAS listens on (loopback only, nginx fronts TLS)";
    };
    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Path to the fully-rendered MAS configuration YAML (typically a sops
        secret). Must contain all secrets (encryption key, signing keys,
        matrix.secret, clients, upstream_oauth2 with the Keycloak provider).
        Generate a starting point with `mas-cli config generate`, then edit
        URLs, add the Keycloak upstream provider, and the Synapse client.
      '';
    };
    synapseExtraConfigFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Path to a YAML fragment loaded into Synapse via extraConfigFiles,
        containing the experimental_features.msc3861 block. Must share the
        admin_token and client_secret with the matrix.secret and clients
        sections of the MAS config.
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
        assertion = mas.synapseExtraConfigFile != null;
        message = "homelab.services.matrix.mas.synapseExtraConfigFile must be set when MAS is enabled";
      }
      {
        assertion = cfg.oidcClientSecretFile == null;
        message = "homelab.services.matrix.oidcClientSecretFile cannot be used together with MAS. MSC3861 disables Synapse's legacy OIDC path; configure Keycloak as an upstream provider in the MAS config instead.";
      }
    ];

    users.users.${masUser} = {
      isSystemUser = true;
      group = masUser;
      home = "/var/lib/${masUser}";
      createHome = true;
    };
    users.groups.${masUser} = { };

    services.postgresql = {
      ensureDatabases = [ masUser ];
      ensureUsers = [
        {
          name = masUser;
          ensureDBOwnership = true;
        }
      ];
    };

    systemd.services.matrix-authentication-service = {
      description = "Matrix Authentication Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "postgresql.service" ];
      requires = [ "postgresql.service" ];
      serviceConfig = {
        User = masUser;
        Group = masUser;
        ExecStartPre = [
          "${pkgs.matrix-authentication-service}/bin/mas-cli database migrate --config=${mas.configFile}"
          "${pkgs.matrix-authentication-service}/bin/mas-cli config sync --config=${mas.configFile}"
        ];
        ExecStart = "${pkgs.matrix-authentication-service}/bin/mas-cli server --config=${mas.configFile}";
        Restart = "on-failure";
        RestartSec = "10s";
        StateDirectory = masUser;
        WorkingDirectory = "/var/lib/${masUser}";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
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
      };
    };

    services.matrix-synapse.extraConfigFiles = [ mas.synapseExtraConfigFile ];
  };
}
