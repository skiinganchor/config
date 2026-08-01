{ config, lib, my-secrets, ... }:
let
  secretsPath = builtins.toString my-secrets;
in
{
  imports = [
    (import ./boot.nix)
    (import ./disko-config.nix)
    (import ./users.nix)
    ./homelab
  ];

  sops.defaultSopsFile = "${secretsPath}/secrets/alertson.yaml";
  sops.age.keyFile = "/etc/sops/age/keys.txt";
  sops.secrets."acme/environment-file" = {
    sopsFile = "${secretsPath}/secrets/shared.yaml";
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

            tcp dport 443 accept comment "443 Nginx"
            # LAN only — the router must never forward these;
            # restricting the source here keeps them private even if it does
            ip saddr { 192.168.0.0/16, 10.0.0.0/8 } tcp dport 22 accept comment "22 SSH"
            ip6 saddr { fe80::/10, fc00::/7 } tcp dport 22 accept comment "same, for link-local/ULA IPv6 LAN clients"
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
    # DHCP on every interface: robust for first boot when the NIC's
    # predictable name (enp*/eno*/eth0) is not yet known. Pin to a single
    # interface once the hardware is installed.
    useDHCP = true;
    hostName = "alertson";
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
      # See: https://github.com/NixOS/nixpkgs/issues/448921
      extraLegoRenewFlags = [ "--ari-disable" ];
    };
  };
}
