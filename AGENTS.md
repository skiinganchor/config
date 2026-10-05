# AGENTS.md — NixOS Config Dev Guide

**Type**: NixOS + Home Manager with Flakes
**Entry**: `flake.nix`
**Dev shell**: `devenv shell`

## Verify Changes

```zsh
nix flake check          # validate flake structure
nixpkgs-fmt .          # format code (auto-fix)
statix check           # lint (reports errors)
prek run --all-files   # run hooks manually
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
flake.nix         # entry point, defines systems
devenv.nix        # dev shell & hooks config
modules/          # reusable modules (git, homelab, nfs_client, gui)
modules/dots/     # dotfiles: zsh, tmux, vscodium, ghostty
modules/machines/ # host-specific: nixos/, emilia/, _common/
src/              # base config: base.nix, home.nix, libvirt.nix
shells/           # dev shells: default.nix, python.nix, go.nix
pkgs/             # package overlays
```

## Flake Systems

- `nixos`: system config for desktop
- `emilia`: low power server with disko based on `emily` from https://git.notthebe.ee/notthebee/nix-config

The `nixos` flake machine is reached by Prometheus through the DNS name `desktop`.
Keep Prometheus scrape targets for that machine as `desktop`, not `nixos`.
The Proxmox machine is reached by Prometheus through the stable DNS target name `saga`.
Home Assistant is reached through the stable DNS target name `homeassistant` in the
`node` exporter job. The provisioned Node Exporter Full dashboard discovers it
automatically from Prometheus labels; do not hard-code it in `dashboards.nix`.

## Monitoring Topology

Grafana and Prometheus run on `alertson`. Physical machines are the NixOS
desktop (`desktop`), the NAS (`nas`), and the Intel NUC / Proxmox host (`saga`).
VM placement:

- `saga`: `emilia` and Home Assistant OS (`homeassistant`). Home Assistant OS
  is managed outside this NixOS repository.
- `nas`: `alertson` (scraped as `localhost` from Prometheus) and Proxmox
  Backup Server (`pbs:9100` in the `node` job).

Node exporter scrape targets carry `machine_type="physical"` or
`machine_type="vm"`; VM targets also carry `hypervisor="saga"` or
`hypervisor="nas"`. Preserve these labels when adding or moving targets:
the provisioned Homelab Machines Overview dashboard uses them to populate
three matrices automatically. Keep the existing `availability` labels for
alerting. New VM exporters belong in the `node` job.

The overview's drilldown UID and variables match the pinned Node Exporter
Full revision in `modules/homelab/services/monitoring/grafana/dashboards.nix`.
If upgrading that dashboard, verify its UID and `ds_prometheus`, `job`,
`nodename`, and `node` variables against `machines-overview.nix`.

## Update Nixpkgs

1. Edit `flake.nix` input version
2. `nix flake update`
3. Commit `flake.lock` separately

## Gotchas

- **Uses `my-secrets`**: private repo via SSH - need ssh-agent for `nix flake update`
- Pre-commit runs `nixpkgs-fmt --check` - will reject unformatted code
- No unit tests - validation is declarative via `nix flake check`
