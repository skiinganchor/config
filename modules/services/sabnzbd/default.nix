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
        if [ -f ${cfg.configFile} ]; then
          cp ${cfg.configFile} ${cfg.configFile}.bak
          sed -i "s/^[[:space:]]*host[[:space:]]*=.*$/host = ${lib.escapeShellArg cfg.host}/" ${cfg.configFile}
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
