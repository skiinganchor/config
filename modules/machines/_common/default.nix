{ config, self, ... }:
let
  homelab = config.homelab;
in
{
  system = {
    stateVersion = self.stateVersion;
  };

  home-manager = {
    useGlobalPkgs = true;
    backupFileExtension = "bak";
    extraSpecialArgs = {
      inherit (self) stateVersion;
      inherit homelab;
    };
  };

  imports = [
    ./nix
  ];

  programs.zsh.enable = true;

  homelab.motd.enable = true;
}
