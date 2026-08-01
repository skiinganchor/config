{ config, ... }:
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
        scrapeTargets = [
          {
            job_name = "node";
            static_configs = [
              { targets = [ "127.0.0.1:9100" ]; }
            ];
          }
        ];
      };
      uptime-kuma.enable = true;
    };
    timeZone = "Europe/Amsterdam";
  };

  # Scraped by the prometheus job above; loopback-only, so no firewall
  # rule is needed.
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9100;
  };
}
