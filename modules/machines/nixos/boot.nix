{ pkgs, ... }:
{
  boot = {
    loader.grub = {
      # Use the GRUB 2 boot loader.
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      useOSProber = true;
      # Define on which hard drive you want to install Grub.
      device = "nodev"; # or "nodev" for efi only
      memtest86.enable = true;
    };
    kernelPackages = pkgs.linuxPackages_latest;
  };
}
