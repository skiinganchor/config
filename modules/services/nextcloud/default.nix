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
      virtualHosts."${config.services.nextcloud.hostName}" = {
        listen = [
          {
            addr = "127.0.0.1";
            port = 8083;
          }
        ];
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
      hostName = "nextcloud";
      configureRedis = true;
      caching = {
        redis = true;
      };
      maxUploadSize = "50G";
      settings = {
        trusted_proxies = [ "127.0.0.1" ];
        overwriteprotocol = "https";
        overwritehost = "cloud.${homelab.baseDomain}";
        overwrite.cli.url = "https://cloud.${homelab.baseDomain}";
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
