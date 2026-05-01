{ stateVersion, ... }:

# here we have system-wide configuration - for user configurations see: src/users.nix
{
  imports = [
    (import ../modules/dots/tmux/default.nix)
    (import ../modules/dots/zsh/default.nix)
  ];

  home = {
    stateVersion = stateVersion;
  };

  programs.git = {
    enable = true;
  };
}
