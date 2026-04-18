{ lib, ... }:
{
  options.homelab.networks = {
    local = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            id = lib.mkOption {
              example = 1;
              type = lib.types.int;
            };
            cidr.v4 = lib.mkOption {
              example = "192.168.2.1";
              type = lib.types.str;
            };
            cidr.v6 = lib.mkOption {
              example = "fd14:d122:ca4c::";
              default = null;
              type = lib.types.nullOr lib.types.str;
            };
          };
        }
      );
    };
  };
}
