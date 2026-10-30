{ lib, ... }:
{
  fileSystems."/".fsType = lib.mkDefault "tmpfs";
  homelab.mainUser = {
    name = "rick";
    group = "rick";
  };
  homelab.services.wireguard-netns.enable = lib.mkForce false;
}
