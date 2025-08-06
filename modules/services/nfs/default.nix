{ config, lib, ... }:

let
  service = "nfs";
  cfg = config.homelab.services.${service};
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable declarative NFS exports for the homelab";
    };
    exports = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          path = lib.mkOption {
            type = lib.types.str;
            description = "Directory on this machine to export via NFS";
          };

          clients = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "List of client rules (e.g., '192.168.1.0/24(rw,sync,no_subtree_check)')";
          };
        };
      });

      default = { };
      description = "NFS exports (server functionality)";
    };
  };

  config = lib.mkIf cfg.enable {
    services.${service}.server = lib.mkIf (cfg.exports != { }) {
      enable = true;
    };

    environment.etc."exports".text = lib.concatStringsSep "\n" (
      lib.mapAttrsToList (_: e:
        lib.concatMapStringsSep "\n" (client: "${e.path} ${client}") e.clients
      ) cfg.exports
    );

    # Basic firewall rules for NFSv4 (2049)
    networking.firewall.allowedTCPPorts = [
      (lib.mkIf (cfg.exports != { }) 2049)
    ];
  };
}
