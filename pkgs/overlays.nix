{ nixpkgs, nixpkgs-unstable, ... }:
let
  overlayConfig = {
    config.allowUnfree = true;
  };
  pkgs-unstable = _: prev: {
    pkgs-unstable = import nixpkgs-unstable {
      inherit (prev.stdenv) system;
      inherit (overlayConfig) config;
    };
  };
in
{
  nix.nixPath = [ "nixpkgs=${nixpkgs}" ];
  nixpkgs = {
    inherit (overlayConfig) config;
    overlays = [
      pkgs-unstable
    ];
  };
}
