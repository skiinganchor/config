{
  config,
  pkgs,
  lib,
  ...
}:
let
  service = "nextcloud";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    adminpassFile = lib.mkOption {
      type = lib.types.path;
    };
    adminuser = lib.mkOption {
      type = lib.types.str;
      default = "someonepowerful";
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/${service}";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "cloud.${homelab.baseDomain}";
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Nextcloud";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "A safe home for all your data";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "nextcloud.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Services";
    };
  };
  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;

      recommendedOptimisation = true;
      recommendedProxySettings = true;

      # Modern SSL configuration
      commonHttpConfig = ''
        # Use TLS 1.3 only for modern security
        ssl_protocols TLSv1.3;
        ssl_ecdh_curve X25519:prime256v1:secp384r1;
        ssl_prefer_server_ciphers off;

        # Add HSTS header to force HTTPS
        add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
      '';

      virtualHosts."${config.services.nextcloud.hostName}" = {
        forceSSL = true;
        # uses security.acme instead
        enableACME = false;
        sslCertificate = "/var/lib/acme/${config.homelab.baseDomain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${config.homelab.baseDomain}/key.pem";
      };
    };
    services.postgresql = {
      enable = true;
      ensureDatabases = [ "nextcloud" ];
      ensureUsers = [
        {
          name = "nextcloud";
          ensureDBOwnership = true;
        }
      ];
    };

    systemd.services."nextcloud-setup" = {
      requires = [ "postgresql.service" ];
      after = [ "postgresql.service" ];
    };

    services.${service} = {
      enable = true;
      package = pkgs.nextcloud31;
      hostName = "cloud.${homelab.baseDomain}";
      https = true;

      configureRedis = true;
      caching = {
        redis = true;
      };

      maxUploadSize = "50G";
      settings = {
        overwriteprotocol = "https";
        mail_smtpmode = "sendmail";
        mail_sendmailmode = "pipe";
        user_oidc = {
          allow_multiple_user_backends = 0;
        };
        forwarded_for_headers = [
          "HTTP_CF_CONNECTING_IP"
        ];
        enabledPreviewProviders = [
          "OC\\Preview\\BMP"
          "OC\\Preview\\GIF"
          "OC\\Preview\\JPEG"
          "OC\\Preview\\Krita"
          "OC\\Preview\\MarkDown"
          "OC\\Preview\\MP3"
          "OC\\Preview\\OpenDocument"
          "OC\\Preview\\PNG"
          "OC\\Preview\\TXT"
          "OC\\Preview\\XBitmap"
          "OC\\Preview\\HEIC"
        ];
      };
      config = {
        dbtype = "pgsql";
        dbuser = "nextcloud";
        dbhost = "/run/postgresql";
        dbname = "nextcloud";
        adminuser = cfg.adminuser;
        adminpassFile = cfg.adminpassFile;
      };
    };
  };
}
