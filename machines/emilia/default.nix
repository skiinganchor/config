{ config, lib, my-secrets, sops-nix, ...}:
let
  secretsPath = builtins.toString my-secrets;
in
{
  imports = [
    sops-nix.nixosModules.sops
    (import ./disko-config.nix)
    (import ./users.nix)
    ./homelab
  ];

  sops.defaultSopsFile = "${secretsPath}/secrets/emilia.yaml";
  sops.secrets."acme/dns-provider" = {};
  sops.secrets."acme/dns-resolver" = {};
  sops.secrets."acme/email" = {};
  sops.secrets."acme/environment-file" = {};
  sops.secrets."duckdns/domains-file" = {};
  sops.secrets."duckdns/token-file" = {};

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };
  boot.initrd = {
    systemd.enable = true;
    # kernel modules for virtualized disks
    availableKernelModules = [ "virtio_scsi" "virtio_pci" "sr_mod" ];
  };

  networking = {
    firewall = {
      enable = true;
      allowedTCPPorts = [
        80
        443
      ];
    };
    useDHCP = false;
    hostName = "emilia";
    interfaces.eth0.useDHCP = true;
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = config.sops.secrets."acme/email".path;
    certs.${config.homelab.baseDomain} = {
      reloadServices = [ "caddy.service" ];
      domain = "${config.homelab.baseDomain}";
      extraDomainNames = [ "*.${config.homelab.baseDomain}" ];
      dnsProvider = config.sops.secrets."acme/dns-provider".path;
      dnsResolver = config.sops.secrets."acme/dns-resolver".path;
      dnsPropagationCheck = true;
      group = config.services.caddy.group;
      environmentFile = config.sops.secrets."acme/environment-file".path;
    };
  };

  services.duckdns = {
    enable = true;
    domainsFile = config.sops.secrets."duckdns/domains-file".path;
    tokenFile = config.sops.secrets."duckdns/token-file".path;
  };
}
