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
        MusicFolder = "${cfg.musicDir}";
        DefaultDownsamplingFormat = "aac";
        LyricsPriority = ".lrc,embedded,.txt";
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
          proxyPass = ''
            http://127.0.0.1:${
              toString config.services.${service}.settings.Port
            }
          '';
        };
        sslCertificate = "/var/lib/acme/${config.homelab.baseDomain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${config.homelab.baseDomain}/key.pem";
      };
    };
  };
}
