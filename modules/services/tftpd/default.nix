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
    services.dnsmasq = {
      enable = true;

      settings = {
        enable-tftp = true;
        tftp-root = cfg.rootDir;
        user = "nobody";
      };
    };
  };
}
