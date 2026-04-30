# AGENTS.md — NixOS Config Dev Guide

**Type**: NixOS + Home Manager with Flakes
**Entry**: `flake.nix`
**Dev shell**: `devenv shell`

## Verify Changes

```bash
nix flake check          # validate flake structure
nixpkgs-fmt .          # format code (auto-fix)
statix check           # lint (reports errors)
pre-commit run --all-files   # run hooks manually
```

## Code Style

- **2 spaces** (enforced by `nixpkgs-fmt`)
- Variables: `camelCase` | Attributes: `kebab-case` | Files: `kebab-case.nix`
- Module header:
  ```nix
  { lib, pkgs, config, ... }:
  let inherit (lib) mkOption types; in
  { options.foo = {...}; config = {...}; imports = [...]; }
  ```
- Use `lib.optionals` for conditional lists, not `if`

## Repo Structure

```
flake.nix          # entry point, defines systems
devenv.nix        # dev shell & hooks config
modules/          # reusable modules (git, homelab, nfs_client, gui)
modules/machines/ # host-specific: nixos/, emilia/, _common/
src/              # base config: base.nix, default.nix, home.nix, containers.nix, libvirt.nix
shells/           # dev shells: default.nix, python.nix, go.nix
pkgs/             # package overlays
dots/             # dotfiles: zsh, tmux, vscodium, ghostty
```

## Flake Systems

- `nixos`: system config for desktop
- `emilia`: low power server with disko based on `emily` from https://git.notthebe.ee/notthebee/nix-config

## Update Nixpkgs

1. Edit `flake.nix` input version
2. `nix flake update`
3. Commit `flake.lock` separately

## Gotchas

- **Uses `my-secrets`**: private repo via SSH - need ssh-agent for `nix flake update`
- Pre-commit runs `nixpkgs-fmt --check` - will reject unformatted code
- No unit tests - validation is declarative via `nix flake check`
