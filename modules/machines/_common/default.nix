{ config, pkgs, self, ... }:
let
  homelab = config.homelab;
in
{
  system = {
    stateVersion = self.stateVersion;
  };

  services.ntp = {
    enable = true;
  };

  nix.gc.automatic = true;

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
    ../../dots/nvim
  ];

  programs.zsh.enable = true;

  homelab.motd.enable = true;

  environment.systemPackages = with pkgs; [
    iperf3
    jq
    ncdu
    tmux
    wget
  ];
}
