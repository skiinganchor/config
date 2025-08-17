{ self, config, lib, pkgs, ... }:

let
  homelab = config.homelab;
  user = "wookie";
in
{
  imports = [
    ../../modules/zsh.nix
  ];

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
      openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJC6x212xkUWdmR5gsxDQSyaZnLhrI/ZFw9C2omrAMy7" ];
      packages = homelab.mainUser.pkgs;
    };

    system.activationScripts.silencezsh.text = ''
      [ ! -e "/home/${user}/.zshrc" ] && echo "# dummy file" > /home/${user}/.zshrc
    '';
  };
}
