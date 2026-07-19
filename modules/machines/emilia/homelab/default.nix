{ config, lib, my-secrets, sops-nix, ... }:
let
  domain = "tapirus.cc";
  mainUserName = "share";
  mainUserGroup = "users";
  secretsPath = builtins.toString my-secrets;
  wg = config.homelab.networks.local.wireguard-ext;
  wgBase = lib.strings.removeSuffix ".1" wg.cidr.v4;
in
{
  imports = [
    sops-nix.nixosModules.sops
  ];

  sops.secrets."db-password" = { };
  sops.secrets."keycloak/db-password" = { };
  sops.secrets."keycloak/oauth2-proxy-env-file" = { };
  sops.secrets."matrix/registration-secret" = {
    owner = "matrix-synapse";
  };
  sops.secrets."matrix/mas/encryption" = { };
  sops.secrets."matrix/mas/signing-key-rsa" = { };
  sops.secrets."matrix/mas/signing-key-ec-1" = { };
  sops.secrets."matrix/mas/signing-key-ec-2" = { };
  sops.secrets."matrix/mas/signing-key-ec-3" = { };
  sops.secrets."matrix/mas/synapse-shared-secret" = {
    owner = "matrix-synapse";
  };
  sops.secrets."matrix/oidc-client-secret" = { };
  sops.secrets."navidrome/env-file" = { };
  sops.secrets."ntfy/env-file" = { };
  sops.secrets."nextcloud/db-password" = {
    key = "db-password";
    owner = "nextcloud";
    group = "nextcloud";
    mode = "0440";
  };
  sops.secrets."nextcloud/admin-password" = { };
  sops.secrets."nextcloud/secrets" = { };
  sops.secrets."slskd/env-file" = { };
  sops.secrets."wireguard-netns/config" = {
    sopsFile = "${secretsPath}/secrets/shared.yaml";
  };

  homelab = {
    baseDomain = domain;
    mainUser = {
      name = mainUserName;
      group = mainUserGroup;
      pkgs = [ ];
    };
    networks.local.wireguard-ext = {
      id = 15;
      cidr = {
        v4 = "10.68.0.1";
        v6 = null;
      };
      dhcp = {
        v4 = false;
        v6 = false;
      };
    };
    nfs_client = {
      enable = true;
      mounts = {
        # rw makes it not readonly
        # hard and intr are often helpful for better behavior during network issues
        media = {
          remoteHost = "192.168.41.5";
          remotePath = "/media";
          localPath = "/mnt/media";
          fsType = "nfs";
          options = [ "rw" "hard" "intr" "vers=4.1" ];
          owner = mainUserName;
          group = mainUserGroup;
        };
        nextcloud = {
          remoteHost = "192.168.41.5";
          remotePath = "/ndata";
          localPath = "/mnt/nextcloud";
          fsType = "nfs";
          options = [ "rw" "hard" "intr" "vers=4.1" ];
          owner = "nextcloud";
          group = "nextcloud";
        };
      };
    };
    services = {
      enable = true;
      audiobookshelf.enable = false;
      bazarr.enable = true;
      deluge.enable = false;
      fail2ban.enable = true;
      homeassistant.enable = true;
      homepage.enable = true;
      immich.enable = false;
      jellyfin.enable = false;
      seerr.enable = true;
      keycloak = {
        enable = true;
        dbPasswordFile = config.sops.secrets."keycloak/db-password".path;
        oauth2ProxyEnvFile = config.sops.secrets."keycloak/oauth2-proxy-env-file".path;
      };
      kvm.enable = true;
      mariadb.enable = true;
      matrix = {
        enable = true;
        calls.enable = false;
        registrationSecretFile = config.sops.secrets."matrix/registration-secret".path;
        # ntfy (UnifiedPush gateway) is resolved via /etc/hosts (the
        # uptime-kuma module maps every vhost to 127.0.0.1) before DNS is
        # consulted, so Synapse reaches it on loopback — but its default
        # ip_range_blacklist drops 127.0.0.0/8. Whitelist the loopback the
        # push actually targets; the LAN IP covers the path if /etc/hosts
        # ever stops shadowing it.
        ipRangeWhitelist = [ "127.0.0.1" "192.168.31.21" ];
        mas = {
          enable = true;
          encryptionSecretFile = config.sops.secrets."matrix/mas/encryption".path;
          signingKeyFiles = map (name: config.sops.secrets."matrix/mas/${name}".path) [
            "signing-key-rsa"
            "signing-key-ec-1"
            "signing-key-ec-2"
            "signing-key-ec-3"
          ];
          sharedSecretFile = config.sops.secrets."matrix/mas/synapse-shared-secret".path;
          upstreamOAuth2 = {
            providerId = "01KT73JSNJTTJ5MDCAEJ7NX2A2";
            clientId = "matrix-auth";
            clientSecretFile = config.sops.secrets."matrix/oidc-client-secret".path;
          };
        };
      };
      navidrome = {
        enable = true;
        environmentFile = config.sops.secrets."navidrome/env-file".path;
      };
      netboot-xyz.enable = false;
      nextcloud = {
        enable = true;
        adminUser = mainUserName;
        adminPassFile = config.sops.secrets."nextcloud/admin-password".path;
        dbUser = "ncadmin";
        dbPassFile = config.sops.secrets."db-password".path;
        ncDbPassFile = config.sops.secrets."nextcloud/db-password".path;
        secretsJsonFile = config.sops.secrets."nextcloud/secrets".path;
      };
      nginx.enable = true;
      ntfy = {
        enable = true;
        environmentFile = config.sops.secrets."ntfy/env-file".path;
      };
      paperless.enable = false;
      prowlarr.enable = true;
      radarr.enable = true;
      sabnzbd = {
        enable = true;
        host = "0.0.0.0";
      };
      slskd = {
        enable = true;
        environmentFile = config.sops.secrets."slskd/env-file".path;
      };
      sonarr.enable = true;
      stirling-pdf.enable = true;
      uptime-kuma.enable = true;
      vaultwarden.enable = false;
      wireguard-netns = {
        enable = true;
        configFile = config.sops.secrets."wireguard-netns/config".path;
        privateIP = "${wgBase}.2";
        dnsIP = wg.cidr.v4;
      };
    };
    timeZone = "Europe/Amsterdam";
  };
}
