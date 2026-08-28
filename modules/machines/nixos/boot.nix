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
    # limited by Nvidia legacy driver 580
    kernelPackages = pkgs.linuxPackages_6_18;
  };
}
