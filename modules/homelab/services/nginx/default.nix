{ config
, pkgs
, lib
, ...
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

        # Restore the real client IP for connections coming through the
        # Cloudflare proxy. CF-Connecting-IP is only honoured when the TCP
        # peer is a Cloudflare address; direct connections keep their
        # socket IP, so the header cannot be spoofed to evade fail2ban.
        # Ranges from https://www.cloudflare.com/ips/
        ${lib.concatMapStringsSep "\n" (range: "set_real_ip_from ${range};") [
          # IPv4
          "103.21.244.0/22"
          "103.22.200.0/22"
          "103.31.4.0/22"
          "104.16.0.0/13"
          "104.24.0.0/14"
          "108.162.192.0/18"
          "131.0.72.0/22"
          "141.101.64.0/18"
          "162.158.0.0/15"
          "172.64.0.0/13"
          "173.245.48.0/20"
          "188.114.96.0/20"
          "190.93.240.0/20"
          "197.234.240.0/22"
          "198.41.128.0/17"
          # IPv6
          "2400:cb00::/32"
          "2606:4700::/32"
          "2803:f800::/32"
          "2405:b500::/32"
          "2405:8100::/32"
          "2a06:98c0::/29"
          "2c0f:f248::/32"
        ]}
        real_ip_header CF-Connecting-IP;
      '';

      # Catch-all for direct-IP scans and unknown SNI: close the
      # connection instead of serving the first configured vhost.
      virtualHosts."_" = {
        default = true;
        onlySSL = true;
        sslCertificate = "/var/lib/acme/${config.homelab.baseDomain}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${config.homelab.baseDomain}/key.pem";
        extraConfig = ''
          return 444;
        '';
      };
    };
  };
}
