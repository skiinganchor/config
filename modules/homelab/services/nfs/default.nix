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

          # uid and gid are used for access control
          uid = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "User ID to own the exported directory (optional)";
          };

          gid = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "Group ID to own the exported directory (optional)";
          };
        };
      });

      default = { };
      description = "NFS exports (server functionality)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure required export directories exist
    systemd.tmpfiles.rules =
      lib.flatten (
        lib.mapAttrsToList
          (_: export:
            let
              ownerUid = if export.uid == null then "root" else toString export.uid;
              ownerGid = if export.gid == null then "root" else toString export.gid;
            in
            [ "d ${export.path} 0755 ${ownerUid} ${ownerGid} -" ]
          )
          cfg.exports
      );

    services.${service} = {
      server = {
        enable = true;
        # Convert your custom export structure to the format expected by the NixOS module
        exports = lib.concatStringsSep "\n" (
          lib.mapAttrsToList
            (_: export:
              lib.concatMapStringsSep "\n" (client: "${export.path} ${client}") export.clients
            )
            cfg.exports
        );
      };
      # Disables old versions of NFS
      settings = {
        nfsd.udp = false;
        nfsd."vers3" = false;
        nfsd."vers4.0" = false;
        nfsd."vers4.1" = false;
        nfsd."vers4.2" = true;
      };
    };

    # Basic firewall rules for NFSv4
    networking.firewall.allowedTCPPorts = [
      2049
    ];
  };
}
