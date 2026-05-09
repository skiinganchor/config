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
      description = "File with slskd credentials";
      type = lib.types.path;
      example = lib.literalExpression ''
        pkgs.writeText "slskd-env" '''
          SLSKD_SLSK_USERNAME=generate
          SLSKD_SLSK_PASSWORD=generate
          # web-ui credentials
          SLSKD_PASSWORD=slskd
          SLSKD_USERNAME=slskd
          SLSKD_JWT=secret
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
        integration.scripts.slskd-import-files = {
          on = [
            "DownloadDirectoryComplete"
            "DownloadFileComplete"
          ];
          run =
            let
              slskd-import-files = pkgs.writeScriptBin "slskd-import-files" ''
                #!${lib.getExe pkgs.bash}
                cd ${cfg.musicDir}/.beets
                HOME=${cfg.musicDir}/.beets ${lib.getExe pkgs.beets} -c ${cfg.beetsConfigFile} import -m -A -q ${cfg.downloadDir}
                import_status=$?
                ${cfg.beetsExportLyricsCommand}
                export_status=$?
                if [ "$import_status" -ne 0 ]; then
                  exit "$import_status"
                fi
                exit "$export_status"
              '';
            in
            {
              executable = "${lib.getExe pkgs.bash}";
              command = "-c ${lib.getExe slskd-import-files}";
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
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.services.${service}.settings.web.port}";
        };
        sslCertificate = "/var/lib/acme/${config.homelab.baseDomain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${config.homelab.baseDomain}/key.pem";
      };
    };
  };
}
