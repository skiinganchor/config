{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.services.fail2ban;
in
{
  options.services.fail2ban = {
    enable = lib.mkEnableOption {
      description = "Enable fail2ban";
    };
    jails = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            serviceName = lib.mkOption {
              example = "vaultwarden";
              type = lib.types.str;
            };
            failRegex = lib.mkOption {
              type = lib.types.str;
              example = "Login failed from IP: <HOST>";
            };
            ignoreRegex = lib.mkOption {
              type = lib.types.str;
              default = "";
            };
            maxRetry = lib.mkOption {
              type = lib.types.int;
              default = 3;
            };
          };
        }
      );
    };
  };
  config = lib.mkIf cfg.enable {
    services.fail2ban = {
      enable = true;
      extraPackages = [
        pkgs.curl
        pkgs.jq
      ];

      jails = lib.attrsets.mapAttrs (name: value: {
        settings = {
          bantime = "30d";
          findtime = "1h";
          enabled = true;
          backend = "systemd";
          journalmatch = "_SYSTEMD_UNIT=${value.serviceName}.service";
          port = "http,https";
          filter = "${name}";
          maxretry = 3;
          action = "cloudflare-token-agenix";
        };
      }) cfg.jails;
    };
  };
}
