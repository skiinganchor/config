{ config, lib, pkgs, ... }:
let
  service = "sabnzbd";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    configFile = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/sabnzbd/sabnzbd.ini";
        description = "Path to config file.";
    };
    host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Defined the host for connection binding.";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "sabnzbd.${homelab.baseDomain}";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "SABnzbd";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "The free and easy binary newsreader";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "sabnzbd.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Downloads";
    };
  };
  config = lib.mkIf cfg.enable (
    let
      # this sets up a service before the execution to dynamically replace the cfg.host
      updateHostScript = pkgs.writeShellScript "update-sabnzbd-host.sh" ''
        configFile=${cfg.configFile}
        hostValue=${lib.escapeShellArg cfg.host}

        if [ -f "$configFile" ]; then
          cp "$configFile" "$configFile.bak"

          # Replace host in [misc] section if it exists
          sed -i '/^\[misc\]/,/^\[.*\]/ {
            /^[[:space:]]*host[[:space:]]*=/ {
              s/^[[:space:]]*host[[:space:]]*=.*$/host = '"$hostValue"'/
              t
            }
          }' "$configFile"

          # Add host if missing in [misc]
          if ! grep -q -E '^[[:space:]]*host[[:space:]]*=' "$configFile" && grep -q '^\[misc\]' "$configFile"; then
            sed -i "/^\[misc\]/a host = $hostValue" "$configFile"
          fi
        fi
      '';
      in {
      services.${service} = {
        enable = true;
        user = homelab.mainUser.name;
        group = homelab.mainUser.group;
      };
      systemd.services.${service} = {
        serviceConfig = {
          ExecStartPre = [ "+${updateHostScript}" ];  # + prefix allows script to modify files as root
        };
      };
    }
  );
}
