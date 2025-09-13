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
    adminPassFile = lib.mkOption {
      type = lib.types.path;
    };
    adminUser = lib.mkOption {
      type = lib.types.str;
      default = "someonepowerful";
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/${service}";
    };
    dbUser = lib.mkOption {
      type = lib.types.str;
      default = "nextcloud";
    };
    dbPassFile = lib.mkOption {
      type = lib.types.path;
    };
    ncDbPassFile = lib.mkOption {
      type = lib.types.path;
    };
    secretsJsonFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to a JSON file containing passwordsalt, secret and instanceid.";
      example = lib.literalExpression ''
        pkgs.writeText "secrets.json" '''
          {
            "passwordsalt": "REPLACE_WITH_RANDOM_64HEX",
            "secret":       "REPLACE_WITH_RANDOM_64HEX",
            "instanceid":   "REPLACE_WITH_RANDOM_12HEX"
          }
        '''
      '';
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
      sslProtocols = "TLSv1.3";
      commonHttpConfig = ''
        # Use TLS 1.3 only for modern security
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

    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
      ensureDatabases = [ "nextcloud" ];
      settings.mysqld.init_file = "/var/lib/mysql/init.sql";
    };

    # This is needed to create a user with a password since ensureUsers is only for socket connections and Nextcloud requires password
    systemd.services.mysql-init = {
      wantedBy = [ "mysql.service" ];
      before = [ "mysql.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script = ''
        DB_PASS=$(cat ${cfg.dbPassFile})
        echo "CREATE OR REPLACE USER '${cfg.dbUser}'@'localhost' IDENTIFIED WITH mysql_native_password USING PASSWORD('$DB_PASS');
        GRANT ALL PRIVILEGES ON nextcloud.* TO '${cfg.dbUser}'@'localhost';
        FLUSH PRIVILEGES;" > /var/lib/mysql/init.sql
        chown mysql:mysql /var/lib/mysql/init.sql
        chmod 0600 /var/lib/mysql/init.sql
      '';
    };

    systemd.services."nextcloud-setup" = {
      requires = [ "mysql.service" ];
      after = [ "mysql.service" ];
    };

    services.${service} = {
      enable = true;
      package = pkgs.nextcloud31;
      hostName = "cloud.${homelab.baseDomain}";
      https = true;

      extraApps = {
        inherit (config.services.nextcloud.package.packages.apps) calendar contacts deck news notes tasks twofactor_webauthn;
        cospend = pkgs.fetchNextcloudApp {
          license = "agpl3Plus";
          url =
            "https://github.com/julien-nc/cospend-nc/releases/download/v3.0.11/cospend-3.0.11.tar.gz";
          sha256 = "adf6e6971899d2c43189d159ebcfe2705cc798ba18c4b0261f6d0d7a38f51eff";
        };

        drawio = pkgs.fetchNextcloudApp {
          license = "agpl3Plus";
          url =
            "https://github.com/jgraph/drawio-nextcloud/releases/download/v3.1.0/drawio-v3.1.0.tar.gz";
          sha256 = "8f19b4ed7fb98bb49bc5f303ac638b3241789927862e661ea5202f44e76f2701";
        };

        phonetrack = pkgs.fetchNextcloudApp {
          license = "agpl3Plus";
          url =
            "https://github.com/julien-nc/phonetrack/releases/download/v0.8.2/phonetrack-0.8.2.tar.gz";
          sha256 = "7c4252186e0ff8e0b97fc3d30131eeadd51bd2f9cc6aa321eb0c1c541f9572c0";
        };

        twofactor_admin = pkgs.fetchNextcloudApp {
          license = "agpl3Plus";
          url =
            "https://github.com/nextcloud-releases/twofactor_admin/releases/download/v4.8.0/twofactor_admin.tar.gz";
          sha256 = "cd9bc7ef17d2a282811b808abd2b9ff03ffa2a7284ba72daf8344b024586a28c";
        };
      };
      extraAppsEnable = true;

      configureRedis = true;
      caching = {
        redis = true;
      };

      maxUploadSize = "50G";
      secretFile = cfg.secretsJsonFile;

      settings = {
        datadirectory = "/mnt/nextcloud/ndata";
        default_phone_region = "BE";
        overwriteprotocol = "https";
        "overwrite.cli.url" = "https://cloud.${homelab.baseDomain}";
        mail_sendmailmode = "pipe";
        mail_smtpmode = "sendmail";
        # execute maintenance jobs between 01:00am UTC and 05:00am UTC
        maintenance_window_start = 1;
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
        dbtype = "mysql";
        dbhost = "127.0.0.1";
        dbname = "nextcloud";
        dbuser = cfg.dbUser;
        dbpassFile = cfg.ncDbPassFile;
        adminuser = cfg.adminUser;
        adminpassFile = cfg.adminPassFile;
      };

      phpOptions."opcache.interned_strings_buffer" = "16";
    };
  };
}
