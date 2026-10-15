{ lib, ... }:
{
  options.homelab.networks = {
    local = lib.mkOption {
      default = { };
      type = lib.types.attrsOf
        (
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
              dhcp.v4 = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = ''
                  Whether to run a DHCPv4 server on the network
                '';
              };
              dhcp.v6 = lib.mkOption {
                type = lib.types.nullOr lib.types.bool;
                default = null;
                description = ''
                  Whether to run a DHCPv6 server on the network. Null enables it
                  whenever the network has an IPv6 range.
                '';
              };
            };
          })
        );
    };
  };
}
