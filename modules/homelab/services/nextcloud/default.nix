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
    monitoredServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "phpfpm-nextcloud"
      ];
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
        forceSSL = true;
        # uses security.acme instead
        enableACME = false;
        extraConfig = ''
          # Add HSTS header to force HTTPS
          add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;

          # Add X-XSS-Protection header for additional XSS protection
          add_header X-XSS-Protection "1; mode=block" always;
        '';
        sslCertificate = "/var/lib/acme/${config.homelab.baseDomain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${config.homelab.baseDomain}/key.pem";
      };
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
      package = pkgs.nextcloud32;
      hostName = cfg.url;
      https = true;

      extraApps = {
        inherit (config.services.nextcloud.package.packages.apps) calendar contacts deck news notes tasks twofactor_webauthn;
        cospend = pkgs.fetchNextcloudApp {
          license = "agpl3Plus";
          url =
            "https://github.com/julien-nc/cospend-nc/releases/download/v3.1.6/cospend-3.1.6.tar.gz";
          sha512 = "52064b5cd5cefc250bd745042100e996bf5266ff701d84c6096b4076e9f5bfe141e2fced79073a5f34e34342a77fbff3edf201bc265b9a386aa3288c6207e0b5";
        };

        drawio = pkgs.fetchNextcloudApp {
          license = "agpl3Plus";
          url =
            "https://github.com/jgraph/drawio-nextcloud/releases/download/v3.1.2/drawio-v3.1.2.tar.gz";
          sha512 = "a177deba645449f130cec1a22723ebbc1145479e797d90b7aff86d30ed6d24be6e8beebdc6ef6d3d1d174ae6570c35a0ca9a14d47e87672842f1d07d19b49691";
        };

        phonetrack = pkgs.fetchNextcloudApp {
          license = "agpl3Plus";
          url =
            "https://github.com/julien-nc/phonetrack/releases/download/v0.9.1/phonetrack-0.9.1.tar.gz";
          sha512 = "67111cbc58b8624ec4a40949982acda82f4aac4d8d76e05156b35d198fa4c7a39572bb7caf59a3fe0be81daa0e79afcbb1c8fec64a3db87bafd23c842ff94d7f";
        };

        twofactor_admin = pkgs.fetchNextcloudApp {
          license = "agpl3Plus";
          url =
            "https://github.com/nextcloud-releases/twofactor_admin/releases/download/v4.9.0/twofactor_admin.tar.gz";
          sha512 = "de1539830e9e9d1971605eb513c5c8aa32d058f30c8b0863e11405030dbdb4259be3ea12dfe524db7b5b29d28642f494ea41df47dcfe789737b6923e55349239";
        };

        user_oidc = pkgs.fetchNextcloudApp {
          license = "agpl3Plus";
          url = "https://github.com/nextcloud-releases/user_oidc/releases/download/v8.2.2/user_oidc-v8.2.2.tar.gz";
          sha512 = "c56973bf164b4309b49bb34ea58ba3cfaa7167e05c7583a230c6332eae6ebecd67506100016b5bbe5965c035780563251ee66d7b08e6ca5671b426858a60e70b";
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
        "app_api.enabled" = false;
        datadirectory = "/mnt/nextcloud/ndata";
        default_phone_region = "NL";
        overwriteprotocol = "https";
        "overwrite.cli.url" = "https://${cfg.url}";
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
