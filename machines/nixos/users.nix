{ self, config, lib, pkgs, ... }:

let
  homelab = config.homelab;
in
{
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."${homelab.mainUser.name}" = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [
      "wheel" # Enable ‘sudo’ for the user.
      "render" # For video transcoding
      "video" # For video transcoding
      "podman"
    ];
    packages = config.homelab.mainUser.pkgs;
  };

  # Global /etc/containers/registries.conf for podman (via NixOS containers module)
  virtualisation.containers.registries.search = [ "docker.io" ];

  home-manager.users = {
    "${homelab.mainUser.name}" = { ... }:
      {
        home = {
          username = homelab.mainUser.name;
          homeDirectory = "/home/${homelab.mainUser.name}";
        };

        # User-scoped ~/.config/containers/registries.conf
        xdg.configFile."containers/registries.conf".text = ''
          [registries.search]
          registries = ['docker.io']
        '';

        programs.git = {
          settings.user = {
            name = config.homelab.git.userName;
            email = config.homelab.git.email;
          };
          includes = lib.optionals homelab.git.createWorkspaces (
            map
              (ws: {
                condition = "gitdir:~/${ws.folderName}/";
                path = "~/${ws.folderName}/.gitconfig";
              })
              homelab.git.workspaces
          );
        };

        home.file = lib.mkIf homelab.git.createWorkspaces (
          lib.listToAttrs (map
            (ws:
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
              })
            homelab.git.workspaces)
        );
      };
  };
  home-manager.sharedModules = [
    # Ghostty still with build issues on v1.2.3 for x86_64-linux
    # (import "${self}/dots/ghostty/default.nix")
    (import "${self}/dots/vscodium/default.nix")
    (import "${self}/src/home.nix")
    (import "${self}/modules/gui/dconf.nix")
    (import "${self}/modules/gui/gnome-terminal.nix")
    (import "${self}/modules/opencode")
  ];
}
