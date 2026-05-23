{ config
, lib
, ...
}:
let
  service = "navidrome";
  inherit (config) homelab;
  cfg = homelab.services.${service};
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/${service}";
    };
    musicDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/media/music/library";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "${service}.${homelab.baseDomain}";
    };
    environmentFile = lib.mkOption {
      type = lib.types.path;
      example = lib.literalExpression ''
        pkgs.writeText "navidrome-env" '''
          ND_LASTFM_APIKEY=abcabc
          ND_LASTFM_SECRET=abcabc
        '''
      '';
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Navidrome";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Self-hosted music streaming service";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "navidrome.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Media";
    };
    role = lib.mkOption {
      type = lib.types.enum [
        "client"
        "server"
      ];
      default = "client";
    };
  };
  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.musicDir} 0775 ${homelab.mainUser.name} ${homelab.mainUser.group} - -"
    ];
    systemd.services.navidrome.serviceConfig.EnvironmentFile = lib.mkIf
      (
        cfg.environmentFile != null
      )
      cfg.environmentFile;
    # Fix for namespace error with NFS mount forcefully disable the conflicting upstream sandboxing potentially added.
    systemd.services.navidrome.serviceConfig = {
      RootDirectory = lib.mkForce "";
      BindReadOnlyPaths = lib.mkForce [ ];
    };
    services.${service} = {
      enable = true;
      user = homelab.mainUser.name;
      group = homelab.mainUser.group;
      settings = {
        DefaultDownsamplingFormat = "aac";
        ExtAuth = {
          # Trust X-User header only from nginx on localhost; without this
          # navidrome ignores the header entirely, and anyone could spoof it.
          TrustedSources = "127.0.0.1/32";
          # Match what the nginx auth_request block sets via proxy_set_header.
          UserHeader = "X-User";
        };
        LogLevel = "debug";
        LyricsPriority = ".lrc,embedded,.txt";
        MusicFolder = "${cfg.musicDir}";
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
        '';
        locations = {
          "/" = {
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

              proxy_pass http://127.0.0.1:${toString config.services.${service}.settings.Port};
            '';
          };
          # Subsonic-compatible API used by mobile clients — bypasses oauth2-proxy
          # because these clients use their own token-based auth and cannot follow
          # an OIDC redirect flow. Clear X-User/X-Email so a client can't forge
          # identity on this unauthenticated path; empty header => Navidrome falls
          # back to standard Subsonic auth.
          "/rest/" = {
            proxyPass = "http://127.0.0.1:${toString config.services.${service}.settings.Port}";
            extraConfig = ''
              proxy_set_header X-User "";
              proxy_set_header X-Email "";
            '';
          };
          # Public share links must remain accessible without a session cookie.
          # Same anti-spoofing as /rest/ clear applies.
          "/share/" = {
            proxyPass = "http://127.0.0.1:${toString config.services.${service}.settings.Port}";
            extraConfig = ''
              proxy_set_header X-User "";
              proxy_set_header X-Email "";
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
