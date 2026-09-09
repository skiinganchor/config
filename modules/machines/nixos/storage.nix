{ config, ... }:

let
  user = config.homelab.mainUser.name;
in
{
  fileSystems."/mnt/storage" = {
    device = "/dev/disk/by-uuid/5f9d6cb4-fec5-4c99-b505-fc3f36007d21";
    fsType = "ext4";

    options = [
      "nofail"

      # Make the filesystem root writable by the main user.
      "X-mount.owner=${user}"
      "X-mount.group=users"
      "X-mount.mode=0755"

      # Show it as a drive in GNOME Files.
      "x-gvfs-show"
      "x-gvfs-name=Storage"
    ];
  };
}
