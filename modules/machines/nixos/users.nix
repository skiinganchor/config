{ self, config, lib, pkgs, ... }:

let
  homelab = config.homelab;
  allUsers = [ homelab.mainUser ] ++ homelab.extraUsers;

  mkSystemUser = u: lib.nameValuePair u.name (
    {
      isNormalUser = true;
      shell = pkgs.zsh;
      extraGroups = [
        "dialout" # Enable for WebSerial writing firmware to microcontrollers like ESP32
        "render" # For video transcoding
        "video" # For video transcoding
        "podman"
      ] ++ lib.optionals u.hasSudo [ "wheel" ];
      packages = u.pkgs;
    }
    // lib.optionalAttrs (u.uid != null) { inherit (u) uid; }
  );

  mkHomeManagerUser = u: lib.nameValuePair u.name {
    home = {
      username = u.name;
      homeDirectory = "/home/${u.name}";
    };

    # User-scoped ~/.config/containers/registries.conf
    xdg.configFile."containers/registries.conf".text = ''
      [registries.search]
      registries = ['docker.io']
    '';

    programs.git = {
      settings.user = {
        name = if u.gitUserName != null then u.gitUserName else config.homelab.git.userName;
        email = if u.gitEmail != null then u.gitEmail else config.homelab.git.email;
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
in
{
  users.users = lib.listToAttrs (map mkSystemUser allUsers);

  home-manager.users = lib.listToAttrs (map mkHomeManagerUser allUsers);

  home-manager.sharedModules = [
    (import "${self}/src/home.nix")
    (import "${self}/modules/dots/ghostty/default.nix")
    (import "${self}/modules/dots/vscodium/default.nix")
    (import "${self}/modules/gui/dconf.nix")
    (import "${self}/modules/gui/gnome-terminal.nix")
    (import "${self}/modules/opencode")
    (import "${self}/modules/dots/zsh/default.nix")
    { programs.zsh.initContent = lib.mkAfter ''eval "$(devenv hook zsh)"''; }
  ];
}
