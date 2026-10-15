{ config
, lib
, pkgs
, ...
}:
let
  service = "slskd";
  inherit (config) homelab;
  cfg = homelab.services.${service};
  ns = homelab.services.wireguard-netns.namespace;
  beets = homelab.services.beets;
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
    downloadDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/media/music/import";
    };
    incompleteDownloadDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/media/music/import.tmp";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "slskd.${homelab.baseDomain}";
    };
    autoImport = lib.mkOption {
      type = lib.types.bool;
      default = beets.enable && !(homelab.services.aurral.enable || homelab.services.lidarr.enable);
      description = ''
        Import completed slskd directories through the shared beets command.
        Enable only when no application needs to approve or consume those files.
        The slskd completion event does not identify the requesting application.
      '';
    };
    environmentFile = lib.mkOption {
      description = ''
        File with slskd credentials. Only Soulseek-network credentials are
        required — the web UI is fronted by oauth2-proxy + Keycloak and
        slskd's built-in auth is disabled.
      '';
      type = lib.types.path;
      example = lib.literalExpression ''
        pkgs.writeText "slskd-env" '''
          SLSKD_SLSK_USERNAME=generate
          SLSKD_SLSK_PASSWORD=generate
        '''
      '';
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "slskd";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Web-based Soulseek client";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "slskd.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Downloads";
    };
  };
  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = map (x: "d ${x} 0775 ${homelab.mainUser.name} ${homelab.mainUser.group} - -") [
      cfg.downloadDir
      cfg.incompleteDownloadDir
    ];
    assertions = [
      {
        assertion = !cfg.autoImport || beets.enable;
        message = "slskd.autoImport requires homelab.services.beets.enable.";
      }
      {
        assertion = !cfg.autoImport || !(homelab.services.aurral.enable || homelab.services.lidarr.enable);
        message = "slskd.autoImport cannot run before Aurral approval or race Lidarr's download handling; see docs/music-workflow.md.";
      }
    ];
    services.${service} = {
      enable = true;
      user = homelab.mainUser.name;
      group = homelab.mainUser.group;
      environmentFile = cfg.environmentFile;
      domain = null;
      settings = {
        # Browser auth is handled by oauth2-proxy + Keycloak at the nginx
        # layer; slskd's built-in login is disabled to avoid a second prompt.
        # Loopback API access (beets, monitoring) stays open because the
        # systemd-socket-proxyd / netns plumbing keeps the listener on 127.0.0.1.
        web.authentication.disabled = true;
        # This hook only adapts slskd's native event to the common importer.
        integration.scripts.slskd-import-files = lib.mkIf cfg.autoImport {
          on = [ "DownloadDirectoryComplete" ];
          run = {
            executable = toString (pkgs.writeShellScript "slskd-beets-import" ''
              set -euo pipefail
              directory="$(${lib.getExe pkgs.jq} -er '.localDirectoryName | select(type == "string" and length > 0)' <<< "$SLSKD_SCRIPT_DATA")"
              root="$(${lib.getExe' pkgs.coreutils "realpath"} -e -- ${lib.escapeShellArg cfg.downloadDir})"
              if [[ "$directory" != /* ]]; then directory="$root/$directory"; fi
              directory="$(${lib.getExe' pkgs.coreutils "realpath"} -e -- "$directory")"
              case "$directory" in
                "$root"/*) ;;
                *) echo "Completed directory is outside the slskd download folder" >&2; exit 1 ;;
              esac
              exec ${beets.importCommand} -q "$directory"
            '');
          };
        };
        directories = {
          downloads = cfg.downloadDir;
          incomplete = cfg.incompleteDownloadDir;
        };
        shares = {
          directories = [ beets.libraryDir ];
          filters = [
            "\.ini$"
            "Thumbs.db$"
            "\.DS_Store$"
          ];
        };
      };
    };
    systemd.sockets = lib.mkIf homelab.services.wireguard-netns.enable {
      "slskd-web-proxy" = {
        enable = true;
        description = "Socket for Proxy to slskd WebUI";
        listenStreams = [ (toString config.services.${service}.settings.web.port) ];
        wantedBy = [ "sockets.target" ];
      };
    };
    systemd.services = {
      slskd = {
        # Fix for namespace error with NFS mount forcefully disable the conflicting upstream sandboxing potentially added.
        serviceConfig.PrivateMounts = lib.mkForce false;
        serviceConfig.ProtectHome = lib.mkForce false;
        serviceConfig.ProtectSystem = lib.mkForce "no";
        serviceConfig.ReadWritePaths = lib.mkForce [ ];

        serviceConfig.ReadOnlyPaths = lib.mkForce [ ];
        serviceConfig.NetworkNamespacePath = lib.attrsets.optionalAttrs homelab.services.wireguard-netns.enable [
          "/var/run/netns/${ns}"
        ];
      }
      // lib.attrsets.optionalAttrs homelab.services.wireguard-netns.enable {
        after = [ "${ns}.service" ];
        bindsTo = [ "netns@${ns}.service" ];
        environment = {
          DOTNET_USE_POLLING_FILE_WATCHER = "true";
        };
        requires = [
          "network-online.target"
          "${ns}.service"
        ];
      };
      "slskd-web-proxy" = lib.attrsets.optionalAttrs homelab.services.wireguard-netns.enable {
        enable = true;
        description = "Proxy to slskd WebUI in Network Namespace";
        requires = [
          "slskd.service"
          "slskd-web-proxy.socket"
        ];
        after = [
          "slskd.service"
          "slskd-web-proxy.socket"
        ];
        unitConfig = {
          JoinsNamespaceOf = "slskd.service";
        };
        serviceConfig = {
          User = config.services.slskd.user;
          Group = config.services.slskd.group;
          ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=5min 127.0.0.1:${
            toString config.services.${service}.settings.web.port
          }";
          PrivateNetwork = "yes";
        };
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
          "/" = {
            extraConfig = ''
              auth_request /oauth2/auth;
              error_page 401 = /oauth2/sign_in;
              auth_request_set $auth_cookie $upstream_http_set_cookie;
              add_header Set-Cookie $auth_cookie;
              add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
              add_header X-XSS-Protection "1; mode=block" always;

              proxy_pass http://127.0.0.1:${toString config.services.${service}.settings.web.port};
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
