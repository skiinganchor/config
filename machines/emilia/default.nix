{ config, lib, my-secrets, sops-nix, ...}:
let
  secretsPath = builtins.toString my-secrets;
in
{
  imports = [
    sops-nix.nixosModules.sops
    (import ./disko-config.nix)
    ./homelab
  ];

  sops.defaultSopsFile = "${secretsPath}/secrets/services.yaml";
  sops.age.keyFile = "/home/share/.config/sops/age/keys.txt";
  sops.secrets."duckdns/domains-file" = {};
  sops.secrets."duckdns/token-file" = {};

  networking = {
    firewall.enable = lib.mkForce false;
    useDHCP = false;
    interfaces = {
      wlan0.useDHCP = true;
      eth0.useDHCP = true;
    };
  };
  
  services.duckdns = {
    enable = true;
    domainsFile = config.sops.secrets."duckdns/domains-file".path;
    tokenFile = config.sops.secrets."duckdns/token-file".path;
  };
}
