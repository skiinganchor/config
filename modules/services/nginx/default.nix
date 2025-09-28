{
  config,
  pkgs,
  lib,
  ...
}:
let
  service = "nginx";
  cfg = config.homelab.services.${service};
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;

      recommendedOptimisation = true;
      recommendedProxySettings = true;

      # Modern SSL configuration
      sslProtocols = "TLSv1.3";
      commonHttpConfig = ''
        # Use TLS 1.3 only for modern security
        ssl_ecdh_curve X25519:prime256v1:secp384r1;
        ssl_prefer_server_ciphers off;
      '';
    };
  };
}
