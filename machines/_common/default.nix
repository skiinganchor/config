{ config, self, ... }:
let
  homelab = config.homelab;
in
{
  homelab.motd.enable = true;

  home-manager = {
    backupFileExtension = "bak";
    sharedModules = [ (import "${self}/src/home.nix") ];
    extraSpecialArgs = {
      inherit (self) stateVersion;
      inherit homelab;
    };
  };
}
