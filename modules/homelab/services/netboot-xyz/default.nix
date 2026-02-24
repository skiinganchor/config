{ config, lib, pkgs, ... }:
let
  service = "netboot-xyz";
  cfg = config.homelab.services.${service};
  tag = "0.7.6-nbxyz7";
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ podman git ];
    virtualisation.oci-containers.containers = {
      ${service} = {
        image = "ghcr.io/netbootxyz/netbootxyz:${tag}";
        autoStart = true;
        ports = [ "0.0.0.0:8080:80" "0.0.0.0:3000:3000" "0.0.0.0:69:69/udp" ];
        # avoids needing to create a range of ports for UDP transfer
        environment = {
          TFTPD_OPTS = "--tftp-single-port";
        };
      };
    };
  };
}
