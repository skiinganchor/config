{ config, lib, my-secrets, sops-nix, ... }:
let
  secretsPath = builtins.toString my-secrets;
  homelab = config.homelab;
in
{
  imports = [
    sops-nix.nixosModules.sops
    ./arr/prowlarr
    ./arr/bazarr
    ./arr/jellyseerr
    ./arr/lidarr
    ./arr/sonarr
    ./arr/radarr
    ./deluge
    ./jellyfin
    ./nextcloud
    ./sabnzbd
    ./wireguard-netns
  ];

  options.homelab.services = {
    enable = lib.mkEnableOption "Settings and services for the homelab";
  };

  config = lib.mkIf (config.homelab.services.enable && homelab.baseDomain != "" ) {
    sops.defaultSopsFile = "${secretsPath}/secrets/services.yaml";
    sops.secrets."acme/dns-provider" = {};
    sops.secrets."acme/dns-resolver" = {};
    sops.secrets."acme/email" = {};
    sops.secrets."acme/environment-file" = {};

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
    security.acme = {
      acceptTerms = true;
      defaults.email = config.sops.secrets."acme/email".path;
      certs.${homelab.baseDomain} = {
        reloadServices = [ "caddy.service" ];
        domain = "${homelab.baseDomain}";
        extraDomainNames = [ "*.${homelab.baseDomain}" ];
        dnsProvider = config.sops.secrets."acme/dns-provider".path;
        dnsResolver = config.sops.secrets."acme/dns-resolver".path;
        dnsPropagationCheck = true;
        group = config.services.caddy.group;
        environmentFile = config.sops.secrets."acme/environment-file".path;
      };
    };
    services.caddy = {
      enable = true;
      globalConfig = ''
        auto_https off
      '';
      virtualHosts = {
        "http://${homelab.baseDomain}" = {
          extraConfig = ''
            redir https://{host}{uri}
          '';
        };
        "http://*.${homelab.baseDomain}" = {
          extraConfig = ''
            redir https://{host}{uri}
          '';
        };
      };
    };
  };
}
