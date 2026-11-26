{ config, lib, pkgs, ... }:
let
  service = "aurral";
  cfg = config.homelab.services.${service};
  inherit (config) homelab;

in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption service;
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/${service}";
    };
    downloadDir = lib.mkOption {
      type = lib.types.externalPath;
      default = "/mnt/media/music/aurral";
      description = ''
        Default writable Library folder for Aurral-managed downloads and flows.
        A saved path in Aurral's web interface takes precedence.
      '';
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "${service}.${homelab.baseDomain}";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 3001;
    };
    directories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "/mnt/media/music" ];
      description = "Additional directories exposed to Aurral, whose backing mounts it must wait for.";
    };
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        TRUST_PROXY = "true";
      };
    };
    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    homepage = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "Aurral";
      };
      description = lib.mkOption {
        type = lib.types.str;
        default = "Lidarr companion for music discovery";
      };
      icon = lib.mkOption {
        type = lib.types.str;
        default = "aurral.svg";
      };
      category = lib.mkOption {
        type = lib.types.str;
        default = "Arr";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      package = pkgs.pkgs-master.aurral;
      inherit (cfg) port openFirewall directories environmentFile;
      environment = cfg.environment // {
        LIBRARY_FOLDER = cfg.downloadDir;
        FILE_BROWSE_ROOTS = cfg.environment.FILE_BROWSE_ROOTS or
          (lib.concatStringsSep "," (lib.unique (cfg.directories ++ [ cfg.downloadDir ])));
      };
      dataDir = cfg.configDir;
    };

    # The NFS server provisions the writable folder. The upstream tmpfiles rule
    # would try to create it or change its metadata as squashed root.
    systemd.tmpfiles.settings."10-aurral" = lib.mkForce { };

    # Root cannot traverse the music tree when systemd sets up bind mounts.
    # The service uses the host mount with permissions enforced by the server.
    systemd.services.aurral = {
      confinement.enable = lib.mkForce false;
      unitConfig.RequiresMountsFor = lib.unique (cfg.directories ++ [ cfg.downloadDir ]);
      serviceConfig = {
        BindPaths = lib.mkForce [ ];
        BindReadOnlyPaths = lib.mkForce [ ];
        ProtectSystem = lib.mkForce "full";
        StateDirectoryMode = "0700";
      };
    };

    services.nginx = {
      virtualHosts."${cfg.url}" = {
        forceSSL = true;
        # uses security.acme instead
        enableACME = false;
        extraConfig = ''
          # Add HSTS header to force HTTPS
          add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;

          # Add X-XSS-Protection header for additional XSS protection
          add_header X-XSS-Protection "1; mode=block" always;
        '';
        locations = {
          "= /api/health/live" = {
            proxyPass = "http://127.0.0.1:${toString cfg.port}";
            extraConfig = ''
              auth_request off;
              ${lib.optionalString (homelab.services.slskd.healthCheckAllowFile != null) "include ${homelab.services.slskd.healthCheckAllowFile};"}
              deny all;
              proxy_set_header X-User "";
              proxy_set_header X-Email "";
              proxy_set_header X-Remote-User "";
              proxy_set_header X-Forwarded-User "";
              proxy_set_header X-Forwarded-Email "";
              proxy_set_header X-Auth-Request-User "";
              proxy_set_header X-Auth-Request-Email "";
              proxy_cache off;
              proxy_intercept_errors off;
              add_header Cache-Control "no-store" always;
              add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
              add_header X-XSS-Protection "1; mode=block" always;
            '';
          };
          "/" = {
            # proxyPass attribute (not inline proxy_pass) so NixOS auto-includes
            # recommendedProxyConfig — otherwise the proxy_set_header below would
            # suppress the inherited Host/X-Forwarded-* headers.
            proxyPass = "http://127.0.0.1:${toString cfg.port}";
            extraConfig = ''
              auth_request /oauth2/auth;
              error_page 401 = /oauth2/sign_in;
              auth_request_set $user  $upstream_http_x_auth_request_user;
              auth_request_set $email $upstream_http_x_auth_request_email;
              proxy_set_header X-User  $user;
              proxy_set_header X-Email $email;
              auth_request_set $auth_cookie $upstream_http_set_cookie;
              add_header Set-Cookie $auth_cookie;
              add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
              add_header X-XSS-Protection "1; mode=block" always;
            '';
          };
          "/oauth2/" = {
            proxyPass = "http://127.0.0.1:4192";
            extraConfig = ''
              proxy_set_header X-Auth-Request-Redirect $request_uri;
              proxy_buffer_size 16k;
              proxy_buffers 4 32k;
              proxy_busy_buffers_size 32k;
            '';
          };
          "= /oauth2/auth" = {
            proxyPass = "http://127.0.0.1:4192";
            extraConfig = ''
              proxy_set_header Content-Length "";
              proxy_pass_request_body off;
            '';
          };
        };
        sslCertificate = "/var/lib/acme/${config.homelab.baseDomain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${config.homelab.baseDomain}/key.pem";
      };
    };
  };
}
