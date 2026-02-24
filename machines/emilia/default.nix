{ config, my-secrets, sops-nix, ... }:
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
  sops.age.keyFile = "/var/lib/sops/age/keys.txt";
  sops.secrets."acme/environment-file" = {
    sopsFile = "${secretsPath}/secrets/shared.yaml";
  };

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
    firewall.enable = false;
    nftables = {
      enable = true;
      ruleset = ''
        table inet filter {
          chain input {
            type filter hook input priority 0;
            policy drop;

            ct state established,related accept
            iifname "lo" accept

            ip protocol icmp accept
            ip6 nexthdr icmpv6 accept

            tcp dport { 22, 443, 5055, 7878, 8686, 8989 } accept comment "22 SSH, 443 Nginx, 5055 Jellyseerrr, 7878 Radarr, 8686 Lidarr, 8989 Sonarr"
          }

          chain forward {
            type filter hook forward priority 0;
            policy drop;
          }

          chain output {
            type filter hook output priority 0;
            policy accept;
          }
        }
      '';
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
      # Disable ARI checks to prevent potential lego crashes
      # See: https://github.com/nixos/nixpkgs/issues/448921
      extraLegoRenewFlags = [ "--ari-disable" ];
    };
  };
}
