{ config
, lib
, ...
}:
{
  # The grafana service runs as the "grafana" user and reads its
  # secret_key at runtime via $__file{...}; sops secrets default to
  # root:root 0400, which grafana could not read.
  sops.secrets."grafana/secret-key" = {
    owner = "grafana";
  };
  sops.secrets."grafana/admin-password" = {
    owner = "grafana";
  };
  sops.secrets."grafana/keycloak-client-secret" = {
    owner = "grafana";
  };
  sops.secrets."alertmanager/ntfy-token" = {
    owner = "alertmanager";
  };
  sops.secrets."alertmanager/smtp-password" = {
    owner = "alertmanager";
  };

  homelab = {
    baseDomain = "tapirus.cc";
    mainUser = {
      name = "share";
      group = "users";
      pkgs = [ ];
    };
    services = {
      enable = true;
      nginx.enable = true;
      grafana = {
        enable = true;
        secretKeyFile = config.sops.secrets."grafana/secret-key".path;
        adminPasswordFile = config.sops.secrets."grafana/admin-password".path;
        oidcClientSecretFile = config.sops.secrets."grafana/keycloak-client-secret".path;
      };
      prometheus = {
        enable = true;
        alerting = {
          enable = true;
          ntfy = {
            tokenFile = config.sops.secrets."alertmanager/ntfy-token".path;
          };
          smtp = {
            enable = true;
            # TODO: fill in with your SMTP details during Phase 0 pre-flight
            smarthost = "smtp.example.com:587";
            authUsername = "alerts@example.com";
            authPasswordFile = config.sops.secrets."alertmanager/smtp-password".path;
            from = "alerts@example.com";
            to = "you@example.com";
          };
        };
        scrapeTargets =
          lib.lists.forEach [ "node" "systemd" ]
            (exporter: {
              job_name = exporter;
              static_configs = [
                {
                  targets = (
                    lib.lists.forEach [ "localhost" "emilia" ] (
                      target: "${target}:${toString config.services.prometheus.exporters.${exporter}.port}"
                    )
                  );
                  labels.availability = "always-on";
                }
                {
                  targets = [ "desktop:${toString config.services.prometheus.exporters.${exporter}.port}" ];
                  labels.availability = "best-effort";
                }
              ];
            })
          ++ [
            {
              job_name = "smartctl";
              static_configs = [
                {
                  targets = [ "desktop:${toString config.services.prometheus.exporters.smartctl.port}" ];
                  labels.availability = "best-effort";
                }
              ];
            }
          ];
      };
      uptime-kuma.enable = true;
    };
    timeZone = "Europe/Amsterdam";
  };
}
