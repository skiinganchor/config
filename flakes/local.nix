{ lib, ... }:
{
  fileSystems."/".fsType = lib.mkDefault "tmpfs";
  homelab.services.wireguard-netns.enable = lib.mkForce false;
}
