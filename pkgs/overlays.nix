{ nixpkgs, nixpkgs-master, nixpkgs-unstable, nixpkgs-staticdev, ... }:
let
  overlayConfig = {
    config.allowUnfree = true;
  };
  pkgs-master = _: prev: {
    pkgs-master = import nixpkgs-master {
      inherit (prev.stdenv) system;
      inherit (overlayConfig) config;
    };
  };
  pkgs-unstable = _: prev: {
    pkgs-unstable = import nixpkgs-unstable {
      inherit (prev.stdenv) system;
      inherit (overlayConfig) config;
    };
  };
  pkgs-staticdev = _: prev: {
    pkgs-staticdev = import nixpkgs-staticdev {
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
      pkgs-master
      pkgs-unstable
      pkgs-staticdev
    ];
  };
}
