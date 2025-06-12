{
  inputs = {
    cfg = {
      url = "github:skiinganchor/config";
    };
  };

  outputs =
    { cfg, ... }:
    let
      mkHost =
        host: systemType:
        systemType {
          hostName = host;
          modules = [
            ./hardware-configuration.nix
            ./local.nix
          ];
        };
    in
    {
      nixosConfigurations = builtins.mapAttrs mkHost {
        nixos = cfg.systemTypes.x86_64;
      };
    };
}
