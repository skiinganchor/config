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
      rules = lib.mkIf cfg.alerting.enable [
        (builtins.toJSON {
          groups = [
            {
              name = "homelab";
              rules = [
                {
                  alert = "InstanceDown";
                  expr = ''up == 0'';
                  for = "2m";
                  labels.severity = "critical";
                  annotations = {
                    summary = "Instance {{ $labels.instance }} down";
                    description = "{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 2 minutes.";
                  };
                }
                {
                  alert = "NodeHighCPU";
                  expr = ''100 - avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100 > 90'';
                  for = "10m";
                  labels.severity = "warning";
                  annotations = {
                    summary = "High CPU usage on {{ $labels.instance }}";
                    description = "CPU usage is above 90% for more than 10 minutes.";
                  };
                }
                {
                  alert = "NodeHighMemory";
                  expr = ''(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) > 0.9'';
                  for = "10m";
                  labels.severity = "warning";
                  annotations = {
                    summary = "High memory usage on {{ $labels.instance }}";
                    description = "Memory usage is above 90% for more than 10 minutes.";
                  };
                }
                {
                  alert = "NodeDiskAlmostFull";
                  expr = ''node_filesystem_avail_bytes{fstype!~"tmpfs|overlay|squashfs"} / node_filesystem_size_bytes < 0.1'';
                  for = "10m";
                  labels.severity = "warning";
                  annotations = {
                    summary = "Disk almost full on {{ $labels.instance }}";
                    description = "{{ $labels.mountpoint }} has less than 10% free space.";
                  };
                }
                {
                  alert = "NodeDiskWillFillIn4Hours";
                  expr = ''predict_linear(node_filesystem_avail_bytes{fstype!~"tmpfs|overlay|squashfs"}[6h], 4 * 3600) < 0'';
                  for = "10m";
                  labels.severity = "critical";
                  annotations = {
                    summary = "Disk filling rapidly on {{ $labels.instance }}";
                    description = "{{ $labels.mountpoint }} is predicted to run out of space within 4 hours.";
                  };
                }
                {
                  alert = "SystemdUnitFailed";
                  expr = ''systemd_unit_state{state="failed"} == 1'';
                  for = "5m";
                  labels.severity = "warning";
                  annotations = {
                    summary = "Systemd unit failed on {{ $labels.instance }}";
                    description = "Unit {{ $labels.name }} has been in failed state for more than 5 minutes.";
                  };
                }
                {
                  alert = "SystemdServiceFlapping";
                  expr = ''changes(systemd_service_restart_total[15m]) > 5'';
                  for = "0m";
                  labels.severity = "warning";
                  annotations = {
                    summary = "Systemd service flapping on {{ $labels.instance }}";
                    description = "Unit {{ $labels.name }} restarted more than 5 times in 15 minutes.";
                  };
                }
              ];
            }
          ];
        })
      ];
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
