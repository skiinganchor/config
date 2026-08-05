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

  # weekly service to free up with SSD firmware blocks no longer in use
  services.fstrim.enable = true;

  # exports metrics for metrics store
  services.prometheus.exporters = {
    systemd = {
      enable = true;
      openFirewall = false;
    };
    node = {
      enable = true;
      openFirewall = false;
    };
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
    ../../dots/nixvim
  ];

  # Preserve SSH agent socket across sudo so nixos-rebuild can fetch
  # git+ssh:// flake inputs (e.g. my-secrets) without needing a separate key.
  security.sudo.extraConfig = ''
    Defaults env_keep += "SSH_AUTH_SOCK"
  '';

  homelab.motd.enable = true;

  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    pkgs-unstable.bleachbit
    iperf3
    jq
    ncdu
    tmux
    wget
  ];
}
