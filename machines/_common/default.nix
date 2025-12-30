{ config, self, ... }:
let
  homelab = config.homelab;
in
{
  homelab.motd.enable = true;

  home-manager = {
    backupFileExtension = "bak";
    extraSpecialArgs = {
      inherit (self) stateVersion;
      inherit homelab;
    };
  };
}
