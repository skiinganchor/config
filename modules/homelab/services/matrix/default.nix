{ pkgs
, lib
, config
, ...
}:
let
  providers = builtins.toFile "providers.json" (builtins.readFile ./providers.json);
  service = "matrix";
  cfg = config.homelab.services.${service};
  hl = config.homelab;
  keyFile = "/run/livekit.key";
  serverConfig."m.server" = "${cfg.url}:443";
  clientConfig = {
    "m.identity_server".base_url = "https://vector.im";
    "m.homeserver".base_url = "https://${cfg.url}";
  } // lib.optionalAttrs cfg.calls.enable {
    "org.matrix.msc4143.rtc_foci" = [
      {
        type = "livekit";
        livekit_service_url = "https://${cfg.url}/livekit/jwt";
      }
    ];
  } // lib.optionalAttrs cfg.mas.enable {
    "org.matrix.msc2965.authentication" = {
      issuer = "https://${cfg.mas.url}/";
      account = "https://${cfg.mas.url}/account/";
    };
  };
in
{
  imports = [ ./mas.nix ];
  options.homelab.services.matrix = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    calls.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable voice and video calls via LiveKit";
    };
    monitoredServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "matrix-synapse"
      ];
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "chat.${hl.baseDomain}";
    };
    registrationSecretFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = lib.literalExpression ''
        pkgs.writeText "matrix-registration-secret.yaml" '''
          registration_shared_secret: "foobar"
        '''
      '';
    };
    oidcClientSecretFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to a file containing the Keycloak OIDC client secret for Synapse. When set, enables SSO login via Keycloak.";
    };
  };
  config = lib.mkIf cfg.enable {
    users.users.matrix-synapse = {
      isSystemUser = true;
      createHome = true;
      group = "matrix-synapse";
    };
    services.postgresql = {
      enable = true;
      initialScript = pkgs.writeText "synapse-init.sql" ''
        CREATE ROLE "matrix-synapse" WITH LOGIN PASSWORD 'synapse';
        CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse"
        TEMPLATE template0
        LC_COLLATE = "C"
        LC_CTYPE = "C";
      '';
    };
    services.livekit = lib.mkIf cfg.calls.enable {
      enable = true;
      openFirewall = true;
      settings.room.auto_create = false;
      inherit keyFile;
    };
    services.lk-jwt-service = lib.mkIf cfg.calls.enable {
      enable = true;
      livekitUrl = "wss://${cfg.url}/livekit/sfu";
      inherit keyFile;
      port = 8068;
    };
    systemd.services.livekit-key = lib.mkIf cfg.calls.enable {
      before = [
        "lk-jwt-service.service"
        "livekit.service"
      ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [
        livekit
        coreutils
        gawk
      ];
      script = ''
        echo "Key missing, generating key"
        echo "lk-jwt-service: $(livekit-server generate-keys | tail -1 | awk '{print $3}')" > "${keyFile}"
      '';
      serviceConfig.Type = "oneshot";
      unitConfig.ConditionPathExists = "!${keyFile}";
    };
    systemd.services.lk-jwt-service = lib.mkIf cfg.calls.enable {
      environment.LIVEKIT_FULL_ACCESS_HOMESERVERS = cfg.url;
    };
    services.nginx = {
      virtualHosts."${cfg.url}" = {
        forceSSL = true;
        enableACME = false;
        extraConfig = ''
          add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
        '';
        sslCertificate = "/var/lib/acme/${hl.baseDomain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${hl.baseDomain}/key.pem";
        locations = {
          "= /.well-known/matrix/server" = {
            extraConfig = ''
              default_type application/json;
              add_header Access-Control-Allow-Origin * always;
              return 200 '${builtins.toJSON serverConfig}';
            '';
          };
          "= /.well-known/matrix/client" = {
            extraConfig = ''
              default_type application/json;
              add_header Access-Control-Allow-Origin * always;
              return 200 '${builtins.toJSON clientConfig}';
            '';
          };
          "/_matrix" = {
            proxyPass = "http://[::1]:8008";
          };
          "/_synapse/client" = {
            proxyPass = "http://[::1]:8008";
          };
          "/" = {
            extraConfig = "return 404;";
          };
        } // lib.optionalAttrs cfg.calls.enable {
          "~ ^/livekit/jwt/(sfu/get|healthz)$" = {
            extraConfig = ''
              rewrite ^/livekit/jwt/(.*) /$1 break;
              proxy_pass http://[::1]:${toString config.services.lk-jwt-service.port};
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };
          "/livekit/sfu" = {
            extraConfig = ''
              rewrite ^/livekit/sfu/?(.*)$ /$1 break;
              proxy_pass http://[::1]:${toString config.services.livekit.settings.port};
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };
        };
      };
    };
    services.matrix-synapse = {
      enable = true;
      extraConfigFiles = lib.optionals (cfg.registrationSecretFile != null) [
        cfg.registrationSecretFile
      ];
      settings = {
        server_name = cfg.url;
        public_baseurl = "https://${cfg.url}";
        enable_registration = false;
        allow_guest_access = false;
        experimental_features = {
          msc4140_enabled = true;
          msc4222_enabled = true;
          msc3266_enabled = true;
        } // lib.optionalAttrs cfg.calls.enable {
          msc4143_enabled = true;
        };
        max_event_delay_duration = "24h";
        oembed = {
          additional_providers = [ providers ];
          disable_default_providers = false;
        };
        oidc_providers = lib.optionals (!cfg.mas.enable && cfg.oidcClientSecretFile != null) [
          {
            idp_id = "keycloak";
            idp_name = "Keycloak";
            issuer = "https://${hl.services.keycloak.url}/realms/sacred";
            client_id = "synapse";
            client_secret_path = cfg.oidcClientSecretFile;
            scopes = [ "openid" "profile" "email" ];
            user_mapping_provider.config = {
              localpart_template = "{{ user.preferred_username }}";
              display_name_template = "{{ user.name }}";
              email_template = "{{ user.email }}";
            };
          }
        ];
        listeners = [
          {
            port = 8008;
            bind_addresses = [ "::1" ];
            type = "http";
            tls = false;
            x_forwarded = true;
            resources = [
              {
                names = [
                  "client"
                  "federation"
                ];
                compress = true;
              }
            ];
          }
        ];
        secondary_directory_servers = [
          "matrix.org"
        ];
      };
    };
  };
}
