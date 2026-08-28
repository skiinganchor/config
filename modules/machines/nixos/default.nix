{ config, lib, my-secrets, nixpkgsUpdate, pkgs, sops-nix, ... }:
let
  secretsPath = builtins.toString my-secrets;
in
{
  imports = [
    sops-nix.nixosModules.sops
    ./boot.nix
    ./homelab
    ./users.nix
  ];

  nix.settings = {
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  sops.secrets = {
    "acme/environment-file" = {
      sopsFile = "${secretsPath}/secrets/shared.yaml";
    };
    "hermes/env-file" = lib.mkIf config.homelab.services.hermes-agent.enable {
      sopsFile = "${secretsPath}/secrets/shared.yaml";
      owner = "hermes";
      group = "hermes";
      mode = "0400";
      restartUnits = [ "hermes-agent.service" ];
    };
  };

  hardware.graphics.enable = true;
  # only accepted from Turing architecture
  # Nvidia configs
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    open = false;
    modesetting.enable = true; # wayland requirement
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
      version = "610.57.04";
      sha256_64bit = "sha256-suk1xmuDuwDAyFe8jg7g/VLekoa0DJzB7sKafOfrEW0=";
      sha256_aarch64 = "sha256-QCefrMBCmpOwuOyXv1k5Gj0iB2CYlPgnG3JToUw/j54=";
      openSha256 = "sha256-rQHOOOY4KL92Ww3KDwh+j4eGU7oNAH8LutZC5wmFnPo=";
      settingsSha256 = "sha256-ZEMo8I8Zc2Tq6RVDNYpAH+f094dUaZiBqO+5f6lIjRI=";
      persistencedSha256 = "sha256-aXmD2VY1RLlgAnlHhOUMWzvMyhI6JTClcFLm4imF/mA=";
    };
  };
  # enable additional exporter for SMART to monitor hard-drive
  services.prometheus.exporters.smartctl.enable = true;

  networking = {
    hostName = "nixos";
    # Open ports in the firewall.
    firewall = {
      enable = true;
      allowedTCPPorts = [
        443 # Nginx
        8096 # Jellyfin
        11111 # Open-WebUI
      ];
      extraInputRules = ''
        ip saddr { 192.168.0.0/16, 10.0.0.0/8 } tcp dport { 9100, 9558, 9633 } accept comment "Prometheus exporters from LAN/WireGuard"
      '';
      checkReversePath = "loose"; # Fix VPN issue
    };
  };

  virtualisation = {
    containers = {
      enable = true;
      # Global /etc/containers/registries.conf for podman (via NixOS containers module)
      registries.search = [ "docker.io" ];
    };
    podman = {
      enable = true;
      autoPrune.enable = true;
      # Create a `docker` alias for podman, to use it as a drop-in replacement
      dockerCompat = true;
      dockerSocket.enable = true;
      # Required for containers under podman-compose to be able to talk to each other.
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  networking.firewall.interfaces.podman0.allowedUDPPorts =
    lib.lists.optionals config.virtualisation.podman.enable
      [ 53 ];

  security.acme = {
    acceptTerms = true;
    defaults.email = "gradient_stiffen452@simplelogin.com";
    certs.${config.homelab.baseDomain} = {
      reloadServices = [ "nginx.service" ];
      domain = "${config.homelab.baseDomain}";
      extraDomainNames = [ "*.${config.homelab.baseDomain}" ];
      dnsProvider = "cloudflare";
      dnsResolver = "1.1.1.1:53";
      dnsPropagationCheck = true;
      group = config.services.nginx.group;
      environmentFile = config.sops.secrets."acme/environment-file".path;
      # Disable ARI checks to prevent potential lego crashes
      # See: https://github.com/nixos/nixpkgs/issues/448921
      extraLegoRenewFlags = [ "--ari-disable" ];
    };
  };

  environment.systemPackages = with pkgs; [
    pkgs-unstable.devenv
    nixpkgsUpdate.packages.${pkgs.stdenv.hostPlatform.system}.nixpkgs-update
    pkgs-unstable.feishin # music player working well with lyrics
  ];
}
