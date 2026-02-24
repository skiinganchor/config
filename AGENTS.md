# AGENTS.md — Development Guidelines for NixOS Configuration

This guide helps agentic developers work efficiently in this Nix-based homelab configuration repository.

## Project Overview

**Type**: NixOS system configuration with Nix Flakes
**Primary Language**: Nix
**Purpose**: Declarative system and home environment configuration using flake.nix
**Key Tools**: `nixpkgs-fmt`, `statix`, `nil`, `nix flake`

---

## Build & Test Commands

### Main Commands

```bash
# Update flake inputs
nix flake update

# Validate flake structure
nix flake check

# Format Nix code (auto-fixes)
nixpkgs-fmt <file.nix>
# Or format directory recursively:
nixpkgs-fmt .

# Lint Nix code (reports issues)
statix check

# Enter dev shell with tools
direnv allow  # or: nix flake enter

# Run pre-commit hooks manually
pre-commit run --all-files
```

### No unit tests in traditional sense
This repo uses declarative validation through `nix flake check` and linting via `statix`. Pre-commit hooks (YAML validation, shellcheck, file formatting) run automatically.

---

## Code Style Guidelines

### Nix Language Conventions

**Indentation & Formatting**
- Use 2 spaces (enforced by `nixpkgs-fmt`)
- Let `nixpkgs-fmt` handle all formatting—never manually align
- Run `nixpkgs-fmt file.nix` before committing

**Naming Conventions**
- Variables: `camelCase` (e.g., `homelab`, `defaultModules`)
- Attributes: `kebab-case` (e.g., `base-domain`, `lock-screen-notifications`)
- Functions: `camelCase` (e.g., `forAllSystems`, `optionalLocalModules`)
- Module files: `kebab-case.nix` (e.g., `nfs-client.nix`, `tailscale.nix`)

**Comments**
- Use `#` for inline comments
- Doc strings in `lib.mkOption`: use `description` and `example` fields
- Multi-line descriptions use `''...''` (Nix string syntax)

### Import & Module Organization

```nix
# Standard header for modules
{ lib, pkgs, config, ... }:

let
  inherit (lib) mkOption types;
in
{
  # 1. Options definition (if module provides options)
  options.moduleName = { ... };

  # 2. Config implementation
  config = { ... };

  # 3. Imports (submodules)
  imports = [
    ./submodule1.nix
    ./submodule2.nix
  ];
}
```

**Guidelines:**
- Always destructure with `inherit` for clarity
- Use `config` and `lib` from function arguments
- Keep modules focused: one concern per file
- Use `lib.mkOption`, `lib.mkEnableOption`, `lib.mkDefault` for options

### Attribute & Option Definition

```nix
# Good: explicit types, defaults, descriptions
myOption = lib.mkOption {
  type = types.str;
  default = "value";
  description = ''
    This option does X. Use it when Y.
  '';
  example = "example-value";
};

# Good: optional with conditional
conditionalOpt = lib.mkOption {
  type = types.nullOr types.str;
  default = null;
  description = "Optional field";
};

# Use lib.mkEnableOption for booleans
enable = lib.mkEnableOption "Feature name";
```

### Type Annotations

- Always declare types in `lib.mkOption` (no type inference)
- Common types: `types.str`, `types.bool`, `types.int`, `types.path`, `types.listOf`, `types.attrs`
- Composite: `types.submodule { ... }` for nested config
- Nullable: `types.nullOr types.str`

### Error Handling & Validation

- Use `lib.mkOption` with type checking (Nix validates at evaluation time)
- Assertions for invariants: `assert condition; body;`
- Use `lib.optional` to conditionally include items (not `if` for list building)
- Use `lib.optionals` (plural) for conditional lists

```nix
# Good: optional list items
items = lib.optionals config.enable ["item1"] ++ ["item2"];

# Good: assertion
assert config.baseDomain != ""; body;
```

### Flake Structure

- `inputs`: External dependencies (nixpkgs, flake inputs)
- `outputs`: System configs, dev shells, and module definitions
- Use `.follows` to align nixpkgs versions across inputs
- Keep `flake.nix` as entry point; move logic to `modules/` and `src/`

---

## File Organization

```
config/
├── flake.nix              # Entry point
├── flake.lock             # Locked versions
├── src/                   # Base system configuration
│   ├── base.nix           # Common system config
│   ├── default.nix        # Nix daemon & store settings
│   ├── containers.nix     # Podman/OCI config
│   ├── home.nix           # Home manager defaults
│   └── libvirt.nix        # Virtualization
├── modules/               # Reusable configuration modules
│   ├── default.nix        # Module options definition
│   ├── git.nix            # Git configuration
│   ├── gui/               # GUI-related modules
│   ├── homelab/           # Homelab services
│   └── ...
├── machines/              # Machine-specific configs
│   ├── _common/           # Shared machine config
│   ├── nixos/             # Default system
│   └── emilia/            # Specific host
├── pkgs/                  # Package definitions & overlays
├── shells/                # Development shells
└── justfile               # Utility recipes
```

---

## Git & Commit Conventions

- **Branch naming**: `feature/name` or `fix/name`
- **Commit messages**: Follow conventional commits
  - `feat(module): add new feature`
  - `fix(git): correct workspace config`
  - `refactor(modules): simplify option structure`
  - `docs: update README`
- **Pre-commit hooks** run automatically:
  - YAML validation (`check-yaml`)
  - Shell script validation (`shellcheck`)
  - File formatting (`end-of-file-fixer`, `trim-trailing-whitespace`)
  - Nix linting on commit (via devenv hooks)

---

## Key Warnings & Anti-Patterns

**❌ DON'T:**
- Use `import` without proper context (use flake inputs instead)
- Create deeply nested module options (flatten into modules/)
- Use `rec` unnecessarily (prefer `inherit`)
- Mix declarative and imperative logic
- Hardcode paths (use `${self}` in flake.nix)
- Ignore type errors from Nix evaluation

**✅ DO:**
- Run `nixpkgs-fmt` and `statix check` before committing
- Use `lib.optionals` for conditional lists
- Define clear option types and defaults
- Keep modules under 300 lines (split if bigger)
- Document complex config with inline comments and `example` fields

---

## Common Tasks

### Add a new system module
1. Create `modules/newmodule.nix` with options and config
2. Add to `modules/default.nix` imports section
3. Run `nixpkgs-fmt modules/newmodule.nix`
4. Test with `nix flake check`

### Update nixpkgs version
1. Edit `flake.nix` input version (e.g., `nixos-25.11` → `nixos-26.05`)
2. Run `nix flake update`
3. Commit `flake.lock` separately

### Debug configuration
```bash
# Enter dev shell
nix flake enter

# Check for errors
statix check

# Inspect option structure
nix flake show
```

---

## Resources

- **Nix Manual**: https://nixos.org/manual/nix/
- **NixOS Options**: https://search.nixos.org/options
- **Home Manager**: https://nix-community.github.io/home-manager/
- **Flakes**: https://nixos.wiki/wiki/Flakes
- **nixpkgs-fmt**: Auto-formats Nix code
- **statix**: Linter for Nix (runs in CI/pre-commit)
