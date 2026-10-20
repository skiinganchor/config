{ nixpkgs, nixpkgs-master, nixpkgs-unstable, ... }:
let
  overlayConfig = {
    config.allowUnfree = true;
  };
  pkgs-master = _: prev: {
    pkgs-master = import nixpkgs-master {
      inherit (prev.stdenv) system;
      inherit (overlayConfig) config;
      overlays = [
        (_final: masterPrev: {
          pythonPackagesExtensions = masterPrev.pythonPackagesExtensions ++ [
            (python-final: python-prev: {
              pyzmq = python-prev.pyzmq.overridePythonAttrs (old: {
                disabledTests = (old.disabledTests or [ ]) ++ [
                  "test_recv_json_cancelled"
                ];
              });
            })
          ];
        })
      ];
    };
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
      pkgs-master
      pkgs-unstable
    ];
  };
}
