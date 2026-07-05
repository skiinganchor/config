{ config, lib, my-secrets, pkgs, sops-nix, ... }:
let
  secretsPath = builtins.toString my-secrets;
  nvidiaLegacy580Master = pkgs.pkgs-master.linuxPackages_latest.nvidiaPackages.legacy_580;
  nvidiaLegacy580 = config.boot.kernelPackages.nvidiaPackages.mkDriver {
    inherit (nvidiaLegacy580Master) version;
    sha256_64bit = nvidiaLegacy580Master.src.outputHash;
    openSha256 = nvidiaLegacy580Master.open.src.outputHash;
    settingsSha256 = nvidiaLegacy580Master.settings.src.outputHash;
    persistencedSha256 = nvidiaLegacy580Master.persistenced.src.outputHash;
  };
in
{
  imports = [
    sops-nix.nixosModules.sops
    ./boot.nix
    ./homelab
    ./users.nix
  ];

  sops.secrets."acme/environment-file" = {
    sopsFile = "${secretsPath}/secrets/shared.yaml";
  };

  hardware.graphics.enable = true;
  # only accepted from Turing architecture
  # Nvidia configs
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    open = false;
    modesetting.enable = true; # wayland requirement
    nvidiaSettings = true;
    package = nvidiaLegacy580;
  };

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
    devenv
  ];
}
