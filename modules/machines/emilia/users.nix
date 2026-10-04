{ self, config, pkgs, ... }:
let
  homelab = config.homelab;
  user = "wookie";
in
{
  config = {
    sops.secrets."admin-user-password" = { neededForUsers = true; };

    # admin user
    users.users."${user}" = {
      isNormalUser = true;
      shell = pkgs.zsh;
      extraGroups = [
        "wheel" # Enable ‘sudo’ for the user.
      ];
      hashedPasswordFile = config.sops.secrets."admin-user-password".path;
      packages = homelab.mainUser.pkgs;
    };

    home-manager.users = {
      "${user}" = { ... }:
        {
          home = {
            username = user;
            homeDirectory = "/home/${user}";
          };
        };
    };
    home-manager.sharedModules = [
      (import "${self}/src/home.nix")
      (import "${self}/modules/dots/zsh/default.nix")
    ];

    # homelab media services user
    users.users."${homelab.mainUser.name}" = {
      isSystemUser = true;
      group = homelab.mainUser.group;
    };
  };
}
