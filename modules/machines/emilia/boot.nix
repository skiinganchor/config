{ pkgs, ... }:
{
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    initrd = {
      systemd.enable = true;
      # kernel modules for virtualized disks
      availableKernelModules = [ "virtio_scsi" "virtio_pci" "sr_mod" ];
    };
    kernelPackages = pkgs.linuxPackages_latest;
    # Emergency swap; prefer keeping workloads in RAM.
    kernel.sysctl."vm.swappiness" = 10;
  };

  swapDevices = [{ device = "/swapfile"; size = 4096; }];
}
