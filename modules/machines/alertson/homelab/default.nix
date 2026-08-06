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
      };
      prometheus = {
        enable = true;
        scrapeTargets = lib.lists.forEach [ "node" "systemd" ] (exporter: {
          job_name = exporter;
          static_configs = [
            {
              targets = (
                lib.lists.forEach [ "localhost" "emilia" ] (
                  target: "${target}:${toString config.services.prometheus.exporters.${exporter}.port}"
                )
              );
            }
          ];
        });
      };
      uptime-kuma.enable = true;
    };
    timeZone = "Europe/Amsterdam";
  };
}
