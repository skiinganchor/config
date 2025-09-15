{ config, my-secrets, sops-nix, ...}:
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
  sops.age.keyFile = "/home/wookie/.config/sops/age/keys.txt";
  sops.secrets."acme/environment-file" = {};

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
        443 # Nginx
        # 3000 # Netboot.xyz
        5055 # Jellyseerrr
        6767 # Bazarr
        7878 # Radarr
        8080 # Sabnzbd
        8686 # Lidarr
        8989 # Sonarr
        9696 # Prowlarr
      ];
      # allowedUDPPorts = [ 69 ]; # TFTP
    };
    useDHCP = false;
    hostName = "emilia";
    interfaces.eth0.useDHCP = true;
  };

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
    };
  };
}
