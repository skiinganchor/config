{ pkgs, ... }:
{
  boot = {
    loader.grub = {
      # Use the GRUB 2 boot loader.
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      useOSProber = true;
      # efi.efiSysMountPoint = "/boot/efi";
      # Define on which hard drive you want to install Grub.
      device = "nodev"; # or "nodev" for efi only
    };
    kernelPackages = pkgs.linuxPackages_latest;
  };
}
