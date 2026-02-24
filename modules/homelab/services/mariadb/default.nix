{ config
, pkgs
, lib
, ...
}:
let
  service = "mariadb";
  cfg = config.homelab.services.${service};
  # Build list of databases to ensure based on enabled services
  ensureDatabases = lib.filter (db: db != "") [
    (if config.homelab.services.keycloak.enable then "keycloak" else "")
    (if config.homelab.services.nextcloud.enable then "nextcloud" else "")
  ];
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    monitoredServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "mysql"
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    services.mysql = {
      enable = true;
      package = pkgs.mariadb;
      ensureDatabases = ensureDatabases;
      settings.mysqld.init_file = "/var/lib/mysql/init.sql";
    };
  };
}
