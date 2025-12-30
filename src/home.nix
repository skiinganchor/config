{ stateVersion, ... }:

# here we have system-wide configuration - for user configurations see: src/users.nix
{
  imports = [
    (import ../dots/zsh/default.nix)
  ];

  home = {
    stateVersion = stateVersion;
  };

  programs.git = {
    enable = true;
  };
}
