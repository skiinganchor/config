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

  programs.vim = {
    enable = true;
    extraConfig = ''
      noremap <Up> <Nop>
      noremap <Down> <Nop>
      noremap <Left> <Nop>
      noremap <Right> <Nop>
      inoremap <Up> <Nop>
      inoremap <Down> <Nop>
      inoremap <Left> <Nop>
      inoremap <Right> <Nop>
    '';
  };
}
