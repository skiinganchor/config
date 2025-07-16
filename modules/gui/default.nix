{ pkgs, lib, config, ... }:

{
  imports = [
    ./gnome.nix
    ./vscode.nix
    ./xdg.nix
  ];
}
