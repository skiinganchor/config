{ stateVersion, ... }:

# here we have system-wide configuration - for user configurations see: machines/<machine-name>/users.nix
{
  imports = [
    (import ../modules/dots/tmux/default.nix)
  ];

  home = {
    stateVersion = stateVersion;
  };

  programs.git = {
    enable = true;
  };
}
