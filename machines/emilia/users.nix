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
      packages = homelab.mainUser.pkgs;
    };
  };
}
