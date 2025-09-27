{ pkgs, ... }:
{
  shell = pkgs.mkShell {
    nativeBuildInputs = with pkgs; [
      libcap
      go
      gcc
      delve
    ];
    NIX_HARDENING_ENABLE = "";
  };
}
