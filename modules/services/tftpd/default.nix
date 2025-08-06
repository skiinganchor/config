{ config, lib, ... }:
let
  service = "tftpd";
  cfg = config.homelab.services.${service};
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    rootDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/${service}";
    };

  };
  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      path = cfg.rootDir;
    };
    # creates rootDir folder
    systemd.tmpfiles.rules = [
      "d ${cfg.rootDir} 0755 root root -"
    ];
  };
}
