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
    services.${service}.server = {
      enable = true;

      # Convert your custom export structure to the format expected by the NixOS module
      exports = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (_: export:
          lib.concatMapStringsSep "\n" (client: "${export.path} ${client}") export.clients
        ) cfg.exports
      );
    };

    # Basic firewall rules for NFSv4
    networking.firewall.allowedTCPPorts = [
      2049
    ];
  };
}
