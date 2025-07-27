{ self, config, lib, pkgs, ... }:

let
  homelab = config.homelab;
in
{
  imports = [
    ../../modules/zsh.nix
  ];

  config = {
    sops.secrets."admin-user-password" = { neededForUsers = true; };

    # admin user
    users.users.wookie = {
      isNormalUser = true;
      shell = pkgs.zsh;
      extraGroups = [
        "wheel" # Enable ‘sudo’ for the user.
      ];
      hashedPasswordFile = config.sops.secrets."admin-user-password".path;
      openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJC6x212xkUWdmR5gsxDQSyaZnLhrI/ZFw9C2omrAMy7" ];
      packages = homelab.mainUser.pkgs;
    };
  };
}
