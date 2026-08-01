{ pkgs, ... }:
{
  boot = {
    loader = {
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        # "nodev" for EFI-only installs; GRUB goes on the ESP, not a disk MBR
        device = "nodev";
      };
      # disko-config.nix mounts the ESP at /boot; with the nixpkgs default
      # (/boot/efi) grub-install --removable would place BOOTX64.EFI one
      # directory too deep on the ESP and UEFI would not find it.
      efi.efiSysMountPoint = "/boot";
    };
    initrd = {
      systemd.enable = true;
      # Superset covering virtio (VM), SATA/AHCI, NVMe and USB storage so
      # the initrd finds the root disk regardless of the final hardware.
      availableKernelModules = [
        "virtio_scsi"
        "virtio_pci"
        "ahci"
        "sd_mod"
        "sr_mod"
        "nvme"
        "usb_storage"
        "uas"
        "xhci_pci"
        "ehci_pci"
        "uhci_hcd"
      ];
    };
    kernelPackages = pkgs.linuxPackages_latest;
  };
}
