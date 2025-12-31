{ stateVersion, ... }:

# here we have system-wide configuration - for user configurations see: src/users.nix
{
  imports = [
    (import ../dots/tmux/default.nix)
    (import ../dots/zsh/default.nix)
  ];

  home = {
    stateVersion = stateVersion;
  };

  programs.git = {
    enable = true;
  };
}
