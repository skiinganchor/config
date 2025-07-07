{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    (import ./disko-config.nix)
  ];

  boot = {
    kernelPackages = lib.mkDefault pkgs.linuxKernel.packages.linux_rpi4;
    kernelParams = [
      "cgroup_enable=memory"
      "cgroup_enable=cpuset"
      "cgroup_memory=1"
    ];
  };
  hardware = {
    bluetooth.enable = true;
  };

  networking = {
    firewall.enable = lib.mkForce false;
    useDHCP = false;
    interfaces = {
      wlan0.useDHCP = true;
      eth0.useDHCP = true;
    };
  };
}
