{ config
, pkgs
, lib
, ...
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
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/nextcloud/ndata";
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
            "instanceid":   "REPLACE_WITH_RANDOM_12HEX",
            "oidc_login_client_secret": "REPLACE_WITH_YOUR-KEYCLOAK-SECRET"
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
      package = pkgs.nextcloud33;
      hostName = cfg.url;
      https = true;

      extraApps = {
        inherit (config.services.nextcloud.package.packages.apps)
          calendar
          contacts
          cospend
          deck
          news
          notes
          oidc_login
          phonetrack
          tasks
          twofactor_admin
          twofactor_webauthn;

        drawio = pkgs.fetchNextcloudApp {
          license = "agpl3Plus";
          url =
            "https://github.com/arnowelzel/drawio-nextcloud/releases/download/v4.3.0/drawio-v4.3.0.tar.gz";
          hash = "sha256-nVcO2V0zo7VdL/o8c6IRbiIqFnGBH7NdqL/eefQ/ip0=";
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
        datadirectory = "${homelab.services.nextcloud.dataDir}";
        default_phone_region = "NL";
        overwriteprotocol = "https";
        "overwrite.cli.url" = "https://${cfg.url}";
        mail_sendmailmode = "pipe";
        mail_smtpmode = "sendmail";
        # execute maintenance jobs between 01:00am UTC and 05:00am UTC
        maintenance_window_start = 1;
        # authentication related
        user_oidc = {
          allow_multiple_user_backends = 0;
        };
        allow_user_to_change_display_name = false;
        lost_password_link = "disabled";
        oidc_login_provider_url = "https://${homelab.services.keycloak.url}/realms/sacred";
        oidc_login_client_id = "nextcloud";
        oidc_login_auto_redirect = true;
        oidc_login_end_session_redirect = true;
        oidc_login_logout_url = "https://${homelab.services.nextcloud.url}/apps/oidc_login/oidc";
        oidc_login_hide_password_form = false;
        oidc_login_use_id_token = true;
        oidc_login_attributes = lib.mkForce {
          "id" = "preferred_username";
          "name" = "name";
          "birthdate" = "birthdate";
          "mail" = "email";
          "groups" = "nextcloud_groups";
          "quota" = "nextcloud_quota";
        };
        oidc_login_default_group = "oidc";
        oidc_login_use_external_storage = false;
        # temporarily remove 'openid' from scope since there is a duplication issue
        # see: https://github.com/jumbojett/OpenID-Connect-PHP/pull/467
        oidc_login_scope = "openid profile email";
        oidc_login_proxy_ldap = false;
        oidc_login_disable_registration = true;
        oidc_login_redir_fallback = false;
        oidc_login_alt_login_page = "assets/login.php";
        oidc_login_tls_verify = true;
        oidc_create_groups = false;
        oidc_login_webdav_enabled = false;
        oidc_login_password_authentication = false;
        oidc_login_public_key_caching_time = 86400;
        oidc_login_min_time_between_jwks_requests = 10;
        oidc_login_well_known_caching_time = 86400;
        oidc_login_update_avatar = false;
        oidc_login_code_challenge_method = "S256";

        # Take the client IP that nginx computed (real_ip from Cloudflare
        # ranges) rather than trusting a client-suppliable CF header, so
        # fail2ban bans cannot be spoofed or evaded.
        trusted_proxies = [ "127.0.0.1" ];
        forwarded_for_headers = [
          "HTTP_X_FORWARDED_FOR"
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
