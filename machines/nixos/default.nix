{ ... }:
{
  imports = [
    ./users.nix
  ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.efiInstallAsRemovable = true;
  boot.loader.grub.useOSProber = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  boot.loader.grub.device = "nodev"; # or "nodev" for efi only

  networking = {
    hostName = "nixos";
    # Open ports in the firewall.
    firewall = {
      enable = true;
      allowedTCPPorts = [
        5055 # Jellyseerrr
        8096 # Jellyfin
        11111 # Open-WebUI
      ];
      checkReversePath = "loose"; # Fix VPN issue
    };
  };
}
