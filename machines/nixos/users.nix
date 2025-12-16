{ self, config, lib, pkgs, ... }:

let
  homelab = config.homelab;
in
{
  imports = [
    ../../modules/zsh.nix
  ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."${homelab.mainUser.name}" = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [
      "docker" # Run docker without ‘sudo’
      "wheel" # Enable ‘sudo’ for the user.
      "render" # For video transcoding
      "video" # For video transcoding
    ];
    packages = config.homelab.mainUser.pkgs;
  };

  home-manager = {
    sharedModules = [ (import "${self}/src/home.nix") ];
    extraSpecialArgs = {
      inherit (self) stateVersion;
      inherit homelab;
    };
  };

  home-manager.users = {
    "${homelab.mainUser.name}" = { ... }:
    {
      home = {
        username = homelab.mainUser.name;
        homeDirectory = "/home/${homelab.mainUser.name}";
      };

      programs.git = {
        settings.user = {
          name = config.homelab.git.userName;
          email = config.homelab.git.email;
        };
        includes = lib.optionals homelab.git.createWorkspaces (
          map (ws: {
            condition = "gitdir:~/${ws.folderName}/";
            path = "~/${ws.folderName}/.gitconfig";
          }) homelab.git.workspaces
        );
      };

      home.file = lib.mkIf homelab.git.createWorkspaces (
        lib.listToAttrs (map (ws:
          {
            name = "${ws.folderName}/.gitconfig";
            value = {
              text = ''
                [user]
                  email = ${ws.email}
                  name = ${ws.userName}
                ${lib.optionalString (ws.sshKeyFile != null) ''
                [core]
                  sshCommand = "ssh -i ${ws.sshKeyFile} -o IdentitiesOnly=yes"
                ''}
              '';
            };
          }) homelab.git.workspaces)
      );
    };
  };
}
