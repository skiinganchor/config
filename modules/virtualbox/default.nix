{ config, ... }:

let
  homelab = config.homelab;
  vboxUser = homelab.mainUser.name;
in
{
  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ vboxUser ];
}
