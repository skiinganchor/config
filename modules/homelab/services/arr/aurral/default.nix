{ config, lib, pkgs, ... }:
let
  service = "aurral";
  cfg = config.homelab.services.${service};
  inherit (config) homelab;
  beets = homelab.services.slskd;
  importAlbum = pkgs.writeShellScript "aurral-beets-import-album" ''
    export BEETSDIR=/var/lib/slskd-import-files
    ${lib.getExe pkgs.pkgs-unstable.beets} -c ${beets.beetsConfigFile} import -m "$1"
    import_status=$?
    ${lib.optionalString beets.beetsLyrics.enable ''
      ${beets.beetsExportLyricsCommand}
      export_status=$?
      if [ "$import_status" -eq 0 ]; then
        exit "$export_status"
      fi
    ''}
    exit "$import_status"
  '';
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
      type = lib.types.externalPath;
      default = "/mnt/media/music/aurral";
      description = ''
        Aurral's managed download folder. Enforced on service startup, including
        installations with a different path saved in the web UI.
        Existing files are not moved when this option changes.
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
        DOWNLOAD_FOLDER = cfg.downloadDir;
        FILE_BROWSE_ROOTS = cfg.environment.FILE_BROWSE_ROOTS or
          (lib.concatStringsSep "," (lib.unique (cfg.directories ++ [ cfg.downloadDir ])));
      };
      dataDir = cfg.configDir;
      user = homelab.mainUser.name;
      group = homelab.mainUser.group;
    };

    # The confined NFS bind fails with 226/NAMESPACE on Emilia.
    # Use the host mount as Lidarr does while keeping system paths read-only.
    systemd.services.aurral = {
      confinement.enable = lib.mkForce false;
      unitConfig.RequiresMountsFor = lib.unique (cfg.directories ++ [ cfg.downloadDir ]);
      preStart = ''
        ${lib.getExe' pkgs.coreutils "install"} -d -m 0770 -- ${lib.escapeShellArg cfg.downloadDir}
        ${lib.getExe pkgs.python3} ${./configure-download-folder.py}
      '';
      serviceConfig = {
        BindPaths = lib.mkForce [ ];
        BindReadOnlyPaths = lib.mkForce [ ];
        ProtectSystem = lib.mkForce "full";
      };
    };

    # Keep imports explicit: moving Aurral's managed files can invalidate its
    # playback paths. Use the same beets configuration and lock as slskd.
    environment.systemPackages = lib.optionals homelab.services.slskd.enable [
      (pkgs.writeShellScriptBin "aurral-beets-import" ''
        set -euo pipefail
        if [ "$#" -ne 1 ]; then
          echo "Usage: aurral-beets-import <artist/album>" >&2
          exit 2
        fi
        download_root="$(${lib.getExe' pkgs.coreutils "realpath"} -e -- ${lib.escapeShellArg cfg.downloadDir})"
        album="$(${lib.getExe' pkgs.coreutils "realpath"} -e -- "$download_root/$1")"
        case "$album" in
          "$download_root"/_flows|"$download_root"/_flows/*|"$download_root"/aurral-weekly-flow|"$download_root"/aurral-weekly-flow/*)
            echo "Temporary flow tracks and playlist metadata are not library imports" >&2
            exit 2
            ;;
          "$download_root"/*/*) ;;
          *)
            echo "Select an album directory inside $download_root" >&2
            exit 2
            ;;
        esac
        test -d "$album"
        exec sudo -u ${lib.escapeShellArg homelab.mainUser.name} \
          ${lib.getExe' pkgs.util-linux "flock"} \
          ${lib.escapeShellArg "${homelab.services.slskd.musicDir}/.beets/import.lock"} \
          ${importAlbum} "$album"
      '')
    ];

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
