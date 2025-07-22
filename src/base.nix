# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

let
  homelab = config.homelab;
in
{
  imports = [
    (import ./users.nix {inherit config lib pkgs;})
  ];

  boot = {};

  # Set your time zone.
  time.timeZone = config.homelab.timeZone;

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = homelab.systemWidePkgs;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  nix = {
    optimise = {
      automatic = true;
      dates = [
        "00:00"
        "12:00"
        "18:00"
      ];
    };
    settings = {
      flake-registry = "";
      auto-optimise-store = true;
      tarball-ttl = 0;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
  };
}
