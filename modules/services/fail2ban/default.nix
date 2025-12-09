{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "fail2ban";
  cfg = config.homelab.services.${service};
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
  };
  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      # increase default bantime of 10min
      bantime = "2h";

      ignoreIP = [
        "192.168.31.8"
      ];

      # The jail file defines how to handle the failed authentication attempts found by the Nextcloud filter
      # Ref: https://docs.nextcloud.com/server/latest/admin_manual/installation/harden_server.html#setup-a-filter-and-a-jail-for-nextcloud
      jails = {

        nextcloud.settings = {
          # START modification to work with syslog instead of logile
          backend = "systemd";
          journalmatch = "SYSLOG_IDENTIFIER=Nextcloud";
          # END modification to work with syslog instead of logile
          enabled = true;
          port = 443;
          protocol = "tcp";
          filter = "nextcloud";
          maxretry = 3;
          bantime = 86400;
          findtime = 43200;
        };
      };
    };

    environment.etc = {
      # Adapted failregex for syslogs
      "fail2ban/filter.d/nextcloud.local".text = pkgs.lib.mkDefault (pkgs.lib.mkAfter ''
        [Definition]
        failregex = ^.*"remoteAddr":"<HOST>".*"message":"Login failed:
                    ^.*"remoteAddr":"<HOST>".*"message":"Two-factor challenge failed:
                    ^.*"remoteAddr":"<HOST>".*"message":"Trusted domain error.
      '');
    };
  };
}
