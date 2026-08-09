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
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
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
      extraCommands = ''
        ${pkgs.nftables}/bin/nft add rule ip filter nixos-fw ip saddr { 192.168.0.0/16, 10.0.0.0/8 } tcp dport { 9100, 9558, 9633 } accept comment "Prometheus exporters from LAN/WireGuard"
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
