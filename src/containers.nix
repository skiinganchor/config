{ config, lib, ... }:
{
  virtualisation = {
    oci-containers.backend = "podman";
    podman = {
      enable = true;
      autoPrune.enable = true;
      # Create a `docker` alias for podman, to use it as a drop-in replacement
      dockerCompat = true;
      dockerSocket.enable = true;
      # Required for containers under podman-compose to be able to talk to each other.
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  networking.firewall.interfaces.podman0.allowedUDPPorts =
    lib.lists.optionals config.virtualisation.podman.enable
      [ 53 ];
}
