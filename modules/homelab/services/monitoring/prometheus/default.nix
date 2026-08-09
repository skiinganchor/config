{ config
, lib
, ...
}:
let
  service = "prometheus";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  prometheusUrl = "http://${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "prometheus.${homelab.baseDomain}";
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 9090;
    };
    scrapeTargets = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
    };
    alerting = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "Prometheus alerting via Alertmanager";
          ntfy = lib.mkOption {
            type = lib.types.submodule {
              options = {
                url = lib.mkOption {
                  type = lib.types.str;
                  default = "https://ntfy.${homelab.baseDomain}";
                };
                topic = lib.mkOption {
                  type = lib.types.str;
                  default = "alerts";
                };
                tokenFile = lib.mkOption {
                  type = lib.types.path;
                  description = ''
                    Path to a file containing the ntfy Bearer token for the alerts topic.
                  '';
                };
              };
            };
            default = { };
          };
          smtp = lib.mkOption {
            type = lib.types.submodule {
              options = {
                enable = lib.mkEnableOption "SMTP email alert receiver";
                smarthost = lib.mkOption {
                  type = lib.types.str;
                  example = "smtp.example.com:587";
                };
                authUsername = lib.mkOption {
                  type = lib.types.str;
                };
                authPasswordFile = lib.mkOption {
                  type = lib.types.path;
                };
                from = lib.mkOption {
                  type = lib.types.str;
                };
                to = lib.mkOption {
                  type = lib.types.str;
                };
              };
            };
            default = { };
          };
        };
      };
      default = { };
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Prometheus";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Monitoring system & time series database";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "prometheus.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Observability";
    };
  };
  config = lib.mkIf cfg.enable {
    services.grafana = {
      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            url = prometheusUrl;
            isDefault = true;
            editable = false;
            uid = "prometheus";
          }
        ];
      };
    };
    services.prometheus = {
      enable = true;
      listenAddress = cfg.listenAddress;
      port = cfg.port;
      globalConfig.scrape_interval = "10s"; # "1m"
      scrapeConfigs = cfg.scrapeTargets;
      alertmanagers = lib.mkIf cfg.alerting.enable [
        {
          static_configs = [
            {
              targets = [ "127.0.0.1:9093" ];
            }
          ];
        }
      ];
      ruleFiles = lib.mkIf cfg.alerting.enable [ ./rules/homelab.yml ];
    };

    services.prometheus.alertmanager = lib.mkIf cfg.alerting.enable {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9093;
      checkConfig = true;
      configuration = {
        route = {
          receiver = "default";
          group_by = [ "alertname" "instance" ];
          group_wait = "30s";
          group_interval = "5m";
          repeat_interval = "4h";
        };
        receivers = [
          {
            name = "default";
            webhook_configs = [
              {
                url = "${cfg.alerting.ntfy.url}/${cfg.alerting.ntfy.topic}";
                send_resolved = true;
                http_config = {
                  authorization = {
                    type = "Bearer";
                    credentials_file = cfg.alerting.ntfy.tokenFile;
                  };
                };
              }
            ];
            email_configs = lib.optionals cfg.alerting.smtp.enable [
              {
                to = cfg.alerting.smtp.to;
                from = cfg.alerting.smtp.from;
                smarthost = cfg.alerting.smtp.smarthost;
                auth_username = cfg.alerting.smtp.authUsername;
                auth_password_file = cfg.alerting.smtp.authPasswordFile;
                send_resolved = true;
              }
            ];
          }
        ];
      };
    };

    users.users.alertmanager = lib.mkIf cfg.alerting.enable {
      isSystemUser = true;
      group = "alertmanager";
    };
    users.groups.alertmanager = lib.mkIf cfg.alerting.enable { };
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
          proxyPass = prometheusUrl;
        };
        sslCertificate = "/var/lib/acme/${homelab.baseDomain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${homelab.baseDomain}/key.pem";
      };
    };
  };
}
