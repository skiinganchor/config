{
  config,
  pkgs,
  ...
}:
{
  sops.secrets.tailscale-auth-key = {};

  environment.systemPackages = [ pkgs.tailscale ];

  networking.firewall.allowedUDPPorts = [ config.services.tailscale.port ];
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  services.tailscale = {
    enable = true;
    authKeyFile = config.sops.secrets.tailscale-auth-key.path;
  };
}
