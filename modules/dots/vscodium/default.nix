{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
    profiles.default.extensions = with pkgs.vscode-extensions; [
      jnoortheen.nix-ide
      mechatroner.rainbow-csv
      mkhl.direnv
      signageos.signageos-vscode-sops
      yzhang.markdown-all-in-one
    ];
  };
}
