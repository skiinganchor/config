{ config
, lib
, pkgs
, ...
}:
let
  service = "homepage-dashboard";
  cfg = config.homelab.services.homepage;
  homelab = config.homelab;
in
{
  options.homelab.services.homepage = {
    enable = lib.mkEnableOption service;
    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = "Environment file containing the Homepage OIDC client secret and authentication secret.";
    };
    monitoredServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        service
      ];
    };
    misc = lib.mkOption {
      default = [ ];
      type = lib.types.listOf (
        lib.types.attrsOf (
          lib.types.submodule {
            options = {
              description = lib.mkOption {
                type = lib.types.str;
              };
              href = lib.mkOption {
                type = lib.types.str;
              };
              siteMonitor = lib.mkOption {
                type = lib.types.str;
              };
              # Icon from https://github.com/homarr-labs/dashboard-icons/tree/main/svg
              icon = lib.mkOption {
                type = lib.types.str;
              };
            };
          }
        )
      );
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = lib.versionAtLeast config.services.${service}.package.version "2.0.0";
      message = "Homepage's built-in OIDC authentication requires homepage-dashboard 2.0 or newer.";
    }];
    services.glances.enable = true;
    services.${service} = {
      enable = true;
      package = pkgs.pkgs-unstable.homepage-dashboard;
      allowedHosts = "homepage.${homelab.baseDomain}";
      environmentFiles = [ cfg.environmentFile ];
      customCSS = ''
        body, html {
          font-family: SF Pro Display, Helvetica, Arial, sans-serif !important;
        }
        .font-medium {
          font-weight: 700 !important;
        }
        .font-light {
          font-weight: 500 !important;
        }
        .font-thin {
          font-weight: 400 !important;
        }
        #information-widgets {
          padding-left: 1.5rem;
          padding-right: 1.5rem;
        }
        div#footer {
          display: none;
        }
        .services-group.basis-full.flex-1.px-1.-my-1 {
          padding-bottom: 3rem;
        };
      '';
      settings = {
        layout = [
          {
            Glances = {
              header = false;
              style = "row";
              columns = 4;
            };
          }
          {
            Arr = {
              header = true;
              style = "column";
            };
          }
          {
            Downloads = {
              header = true;
              style = "column";
            };
          }
          {
            Media = {
              header = true;
              style = "column";
            };
          }
          {
            Services = {
              header = true;
              style = "column";
            };
          }
        ];
        headerStyle = "clean";
        statusStyle = "dot";
        hideVersion = "true";
      };
      services =
        let
          homepageCategories = [
            "Arr"
            "Media"
            "Downloads"
            "Services"
            "Observability"
            "Smart Home"
          ];
          hl = config.homelab.services;
          homepageServices =
            x:
            (lib.attrsets.filterAttrs
              (
                _name: value: value ? homepage && value.homepage.category == x
              )
              homelab.services);
        in
        lib.lists.forEach homepageCategories
          (cat: {
            "${cat}" =
              lib.lists.forEach (lib.attrsets.mapAttrsToList (name: _value: name) (homepageServices "${cat}"))
                (x: {
                  "${hl.${x}.homepage.name}" = {
                    icon = hl.${x}.homepage.icon;
                    description = hl.${x}.homepage.description;
                    href = "https://${hl.${x}.url}";
                    siteMonitor = "https://${hl.${x}.url}";
                  };
                });
          })
        ++ [{ Misc = cfg.misc; }]
        ++ [
          {
            Glances =
              let
                port = toString config.services.glances.port;
              in
              [
                {
                  Info = {
                    widget = {
                      type = "glances";
                      url = "http://localhost:${port}";
                      metric = "info";
                      chart = false;
                      version = 4;
                    };
                  };
                }
                {
                  "CPU Temp" = {
                    widget = {
                      type = "glances";
                      url = "http://localhost:${port}";
                      metric = "sensor:Package id 0";
                      chart = false;
                      version = 4;
                    };
                  };
                }
                {
                  Processes = {
                    widget = {
                      type = "glances";
                      url = "http://localhost:${port}";
                      metric = "process";
                      chart = false;
                      version = 4;
                    };
                  };
                }
                {
                  Network = {
                    widget = {
                      type = "glances";
                      url = "http://localhost:${port}";
                      metric = "network:enp2s0";
                      chart = false;
                      version = 4;
                    };
                  };
                }
              ];
          }
        ];
    };

    systemd.services.${service}.environment = {
      HOSTNAME = "127.0.0.1";
      HOMEPAGE_AUTH_ENABLED = "true";
      HOMEPAGE_EXTERNAL_URL = "https://homepage.${homelab.baseDomain}";
      HOMEPAGE_OIDC_ISSUER = "https://${homelab.services.keycloak.url}/realms/sacred";
      HOMEPAGE_OIDC_CLIENT_ID = "homepage";
      HOMEPAGE_OIDC_NAME = "Keycloak";
      HOMEPAGE_OIDC_AUTO_LOGIN = "true";
    };

    services.nginx = {
      virtualHosts."homepage.${homelab.baseDomain}" = {
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
            proxyPass = "http://127.0.0.1:${toString config.services.${service}.listenPort}";
            extraConfig = ''
              # add_header in a location drops the server-level headers,
              # so the HSTS/XSS headers must be repeated here (gixy
              # rejects the config otherwise)
              add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
              add_header X-XSS-Protection "1; mode=block" always;
            '';
          };
        };
        sslCertificate = "/var/lib/acme/${config.homelab.baseDomain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${config.homelab.baseDomain}/key.pem";
      };
    };
  };
}
