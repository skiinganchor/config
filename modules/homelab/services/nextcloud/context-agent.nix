{ config, lib, pkgs, ... }:
let
  nextcloud = config.homelab.services.nextcloud;
  cfg = nextcloud.contextAgent;
  version = "2.9.1";
  port = 9031;
  stateDir = "/var/lib/nextcloud-context-agent";
  environmentFile = "${stateDir}/secret.env";
  containerService = config.virtualisation.oci-containers.containers.nextcloud-context-agent.serviceName;
  appInfo = pkgs.writeText "context-agent-info.json" (builtins.toJSON {
    id = "context_agent";
    name = "Nextcloud Context Agent";
    inherit version port;
    # Match the USER route in the official release's appinfo/info.xml.
    routes = [{
      url = "^/mcp";
      verb = "POST,GET,DELETE";
      access_level = "USER";
      headers_to_exclude = [ ];
    }];
  });
in
{
  options.homelab.services.nextcloud.contextAgent = {
    enable = lib.mkEnableOption "the official Nextcloud Context Agent MCP server";
  };

  config = lib.mkIf (nextcloud.enable && cfg.enable) {
    # Nix owns the container lifecycle; AppAPI's manual-install deployment
    # registers it without giving the PHP process access to a container socket.
    virtualisation.oci-containers.containers.nextcloud-context-agent = {
      image = "ghcr.io/nextcloud/context_agent:${version}";
      extraOptions = [ "--network=host" ];
      environment = {
        # AppAPI version bundled with the configured Nextcloud 35 package.
        AA_VERSION = "35.0.0";
        APP_ID = "context_agent";
        APP_DISPLAY_NAME = "Nextcloud Context Agent";
        APP_VERSION = version;
        APP_HOST = "127.0.0.1";
        APP_PORT = toString port;
        APP_PERSISTENT_STORAGE = "/nc_app_data";
        NEXTCLOUD_URL = "https://${nextcloud.url}";
      };
      environmentFiles = [ environmentFile ];
      volumes = [ "nextcloud-context-agent-data:/nc_app_data" ];
    };

    systemd.services = {
      nextcloud-context-agent-secret = {
        description = "Initialize the Nextcloud Context Agent internal secret";
        before = [ "${containerService}.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "nextcloud";
          Group = "nextcloud";
          StateDirectory = "nextcloud-context-agent";
          StateDirectoryMode = "0700";
          UMask = "0077";
        };
        script = ''
          if [ ! -s ${environmentFile} ]; then
            secret=$(${pkgs.openssl}/bin/openssl rand -hex 64)
            printf 'APP_SECRET=%s\n' "$secret" > ${environmentFile}.tmp
            mv ${environmentFile}.tmp ${environmentFile}
          fi
        '';
      };

      ${containerService} = {
        requires = [ "nextcloud-context-agent-secret.service" ];
        after = [ "nextcloud-context-agent-secret.service" ];
        wants = [ "nextcloud-context-agent-register.service" ];
        before = [ "nextcloud-context-agent-register.service" ];
      };

      nextcloud-context-agent-register = {
        description = "Register Context Agent with Nextcloud AppAPI";
        wantedBy = [ "multi-user.target" ];
        requires = [ "nextcloud-setup.service" "${containerService}.service" ];
        after = [ "nextcloud-setup.service" "${containerService}.service" "nginx.service" "phpfpm-nextcloud.service" ];
        path = [ config.services.nextcloud.occ pkgs.curl pkgs.jq pkgs.gnugrep ];
        restartTriggers = [ appInfo ];
        serviceConfig = {
          Type = "oneshot";
          User = "nextcloud";
          Group = "nextcloud";
          EnvironmentFile = environmentFile;
          # Match Nextcloud's native OCC services. The wrapper uses these
          # credentials directly instead of trying an unprivileged systemd-run.
          LoadCredential = config.systemd.services.nextcloud-cron.serviceConfig.LoadCredential or [ ];
          UMask = "0077";
          Restart = "on-failure";
          RestartSec = "15s";
          TimeoutStartSec = "300s";
        };
        script = ''
          # AppAPI ships with Nextcloud 35, but may previously have been disabled.
          nextcloud-occ app:enable app_api
          nextcloud-occ app_api:daemon:register nix-context-agent \
            "Nix Context Agent" manual-install http 127.0.0.1 \
            ${lib.escapeShellArg "https://${nextcloud.url}"}

          curl --fail --silent --show-error --retry 60 --retry-connrefused \
            --retry-delay 2 --max-time 5 http://127.0.0.1:${toString port}/heartbeat > /dev/null

          appInfo=$(jq '. + {secret: env.APP_SECRET}' ${appInfo})
          apps=$(nextcloud-occ app_api:app:list)
          if printf '%s\n' "$apps" | grep -q '^context_agent '; then
            nextcloud-occ app_api:app:update context_agent --json-info "$appInfo" --wait-finish
          else
            nextcloud-occ app_api:app:register context_agent nix-context-agent \
              --json-info "$appInfo" --wait-finish
          fi
          nextcloud-occ app_api:app:enable context_agent
        '';
      };
    };
  };
}
