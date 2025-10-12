{
  inputs = {
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixvim = {
      url = "github:nix-community/nixvim/nixos-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    my-secrets = {
      url = "git+ssh://git@github.com/skiinganchor/config-private.git?ref=main&shallow=1";
      flake = false;
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, ... }@inputs:
    with inputs;
    let
      # Modules
      defaultModules = [
        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        nixvim.nixosModules.nixvim
        (import "${self}/pkgs")
        (import "${self}/pkgs/overlays.nix" inputs)
        (import "${self}/modules")
        (import "${self}/src")
        (import "${self}/src/base.nix")
      ];
      optionalLocalModules =
        nix_paths:
        builtins.concatLists (
          inputs.nixpkgs.lib.lists.forEach nix_paths (
            path: inputs.nixpkgs.lib.optional (builtins.pathExists path) (import path)
          )
        );
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
    in
    {
      stateVersion = "25.05";
      systemArch = {
        amd = "x86_64-linux";
      };
      systemTypes = {
        x86_64 =
          attrs:
          nixpkgs.lib.nixosSystem {
            system = self.systemArch.amd;
            specialArgs = {
              inherit self;
              inherit stateVersion;
              my-secrets = inputs.my-secrets;
              sops-nix = inputs.sops-nix;
            };
            modules = [
              (import "${self}/machines/nixos")
              (import "${self}/modules/gui")
              (import "${self}/modules/tailscale")
              (import "${self}/modules/virtualbox")
              (import "${self}/src/libvirt.nix")
            ]
            ++ defaultModules
            ++ optionalLocalModules attrs.modules;
          };
        emilia =
          attrs:
          nixpkgs.lib.nixosSystem {
            system = self.systemArch.amd;
            specialArgs = {
              inherit self;
              inherit stateVersion;
              my-secrets = inputs.my-secrets;
              sops-nix = inputs.sops-nix;
            };
            modules = [
              disko.nixosModules.disko
              (import "${self}/machines/emilia")
            ]
            ++ defaultModules;
          };
      };
      devShells = forAllSystems (
        system:
        let
          pkgs = (import nixpkgs { inherit system; });
          defaultShells = (import "${self}/shells/default.nix" { inherit pkgs; });
          pythonShells = (import "${self}/shells/python.nix" { inherit pkgs; });
          goShells = (import "${self}/shells/go.nix" { inherit pkgs; });
        in
        {
          default = defaultShells.shell;
          python = pythonShells.shell;
          go = goShells.shell;
        }
      );
    };
}
