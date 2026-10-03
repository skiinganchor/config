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
      settings.mysqld =
        {
          init_file = "/var/lib/mysql/init.sql";
        }
        // lib.optionalAttrs config.homelab.services.nextcloud.enable {
          innodb_log_file_size = "256M";
          long_query_time = 2;
          max_heap_table_size = "64M";
          slow_query_log = true;
          tmp_table_size = "64M";
        };
    };
  };
}
