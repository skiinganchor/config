# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```zsh
# Enter dev shell (provides nixpkgs-fmt, nil, statix, nix-tree)
devenv shell

# Validate flake structure
nix flake check

# Format all Nix files (auto-fix)
nixpkgs-fmt .

# Lint Nix files (reports errors, does not auto-fix)
statix check

# Run pre-commit hooks manually
prek run --all-files

# Update flake inputs (requires ssh-agent for my-secrets private repo)
nix flake update
# or
just update
```

## Code Style

- **Indentation**: 2 spaces (enforced by `nixpkgs-fmt`)
- **Variables**: `camelCase` | **Attributes**: `kebab-case` | **Files**: `kebab-case.nix`
- **Module header pattern**:
  ```nix
  { lib, pkgs, config, ... }:
  let inherit (lib) mkOption types; in
  { options.foo = {...}; config = {...}; imports = [...]; }
  ```
- Use `lib.optionals` for conditional lists, not `if`
- Pre-commit rejects unformatted code — always run `nixpkgs-fmt .` before committing

## Architecture

**Entry point**: `flake.nix` — defines two NixOS systems and dev shells.

**Systems**:
- `nixos`: desktop machine with GUI (`modules/gui/`) and libvirt
- `emilia`: low-power homelab server with disko partitioning

Both systems share `defaultModules` which layers: sops-nix, home-manager, nixvim, package overlays, `_common`, top-level modules, and `src/base.nix`.

**Key directories**:
- `src/` — base configs applied to all systems: `base.nix`, `home.nix`, `libvirt.nix`
- `modules/` — top-level options (`homelab.*`) defined in `modules/default.nix`; submodules for git, homelab services, NFS client, GUI, dotfiles
- `modules/machines/_common/` — shared machine config (stateVersion, home-manager defaults, zsh, motd)
- `modules/machines/nixos/` and `modules/machines/emilia/` — host-specific hardware/users/boot
- `modules/dots/` — dotfile modules: zsh, tmux, vscodium, ghostty
- `modules/homelab/services/` — individual service modules (jellyfin, navidrome, immich, nextcloud, keycloak, etc.)
- `pkgs/` — package overlays (`default.nix` adds custom packages, `overlays.nix` applies nixpkgs-unstable/master overlays)
- `shells/` — dev shells: `default.nix`, `python.nix`, `go.nix`
- `flakes/` — local flake overrides

**Options system**: All custom options live under `homelab.*` (defined in `modules/default.nix`). Machine configs set these options; modules read them via `config.homelab.*`.

**Secrets**: Managed via `sops-nix`. The `my-secrets` input is a private SSH repo (`git+ssh://...`) — `ssh-agent` must be running for `nix flake update` to work.

**No unit tests** — validation is declarative via `nix flake check`.
