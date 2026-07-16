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
  beetsPackage = pkgs.pkgs-unstable.beets;
in
{
  imports = [ ./beets.nix ];
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
    beetsConfigFile = lib.mkOption {
      type = lib.types.path;
    };
    beetsExportLyricsCommand = lib.mkOption {
      type = lib.types.str;
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
      cfg.musicDir
      "${cfg.musicDir}/.beets"
      cfg.downloadDir
      cfg.downloadDir
      cfg.incompleteDownloadDir
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
        integration.scripts.slskd-import-files = {
          # Wait for the complete directory so beets sees an album as one unit
          # instead of importing each track as it arrives.
          on = [
            "DownloadDirectoryComplete"
          ];
          run =
            let
              slskd-import-files = pkgs.writeScriptBin "slskd-import-files" ''
                #!${lib.getExe pkgs.bash}

                # Keep a persistent transcript while also forwarding output to
                # systemd-cat, which makes it visible in the slskd journal.
                import_log=${lib.escapeShellArg "${cfg.musicDir}/.beets/slskd-import.log"}
                exec > >(${lib.getExe' pkgs.coreutils "tee"} -a "$import_log") 2>&1
                echo
                echo "[$(${lib.getExe' pkgs.coreutils "date"} --iso-8601=seconds)] DownloadDirectoryComplete received"

                # slskd supplies event data as JSON. Import only the directory
                # that completed; importing the download root would also ingest
                # other albums while their transfers are still in progress.
                if ! event_directory="$(
                  ${lib.getExe' pkgs.coreutils "printf"} '%s' "$SLSKD_SCRIPT_DATA" \
                    | ${lib.getExe pkgs.jq} -er '.localDirectoryName | select(type == "string" and length > 0)'
                )"; then
                  echo "Invalid DownloadDirectoryComplete event data" >&2
                  exit 1
                fi

                download_root="$(${lib.getExe' pkgs.coreutils "realpath"} -e -- ${lib.escapeShellArg cfg.downloadDir})"
                if [[ "$event_directory" = /* ]]; then
                  import_candidate="$event_directory"
                else
                  import_candidate=${lib.escapeShellArg "${cfg.downloadDir}/"}"$event_directory"
                fi
                if ! import_directory="$(${lib.getExe' pkgs.coreutils "realpath"} -e -- "$import_candidate")"; then
                  echo "Completed download directory does not exist: $import_candidate" >&2
                  exit 1
                fi
                case "$import_directory" in
                  "$download_root"/*) ;;
                  *)
                    echo "Refusing to import directory outside $download_root: $import_directory" >&2
                    exit 1
                    ;;
                esac
                echo "Importing completed directory: $import_directory"

                # slskd can finish multiple downloads at once. Hold an
                # exclusive lock so only one importer moves files or writes the
                # SQLite library at a time. The lock is released on process exit.
                exec 9>${lib.escapeShellArg "${cfg.musicDir}/.beets/import.lock"}
                ${lib.getExe' pkgs.util-linux "flock"} 9

                # Keep beets' state in the writable library directory. Verbose
                # output records why a candidate was accepted or skipped; -m
                # moves matches and -q accepts only strong recommendations.
                cd ${lib.escapeShellArg "${cfg.musicDir}/.beets"}
                HOME=${lib.escapeShellArg "${cfg.musicDir}/.beets"} \
                  ${lib.getExe beetsPackage} \
                  -v \
                  -c ${cfg.beetsConfigFile} \
                  import -m -q "$import_directory"
                import_status=$?

                # Refresh sidecars even after a partial import, but preserve the
                # import error as the script's primary failure status.
                ${cfg.beetsExportLyricsCommand}
                export_status=$?
                if [ "$import_status" -ne 0 ]; then
                  exit "$import_status"
                fi
                exit "$export_status"
              '';
            in
            {
              executable = "${lib.getExe' pkgs.systemd "systemd-cat"}";
              arglist = [
                "--identifier=slskd-import"
                (lib.getExe pkgs.bash)
                (lib.getExe slskd-import-files)
              ];
            };
        };
        directories = {
          downloads = cfg.downloadDir;
          incomplete = cfg.incompleteDownloadDir;
        };
        shares = {
          directories = [ cfg.musicDir ];
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
