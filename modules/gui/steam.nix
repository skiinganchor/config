{ pkgs, lib, ... }:
{
  config = lib.mkIf (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
    programs.steam = {
      enable = true;
      package = pkgs.steam;
      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
    };
  };
}
