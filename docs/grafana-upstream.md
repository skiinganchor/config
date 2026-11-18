# Grafana's private upstream on Emilia

Emilia serves `https://monitor.tapirus.cc` and proxies Grafana on Alertson port
3000. Its `alertson-ip` secret is a **single IPv4 address**, without a port,
CIDR suffix, quotes inside the value, or trailing newline.

## Add or update the address

In `skiinganchor/config-private`, use the existing SOPS editor and age recipient
from `.sops.yaml` (the creation rule already covers `secrets/emilia.yaml`):

```console
sops secrets/emilia.yaml
```

Add a top-level `alertson-ip` YAML string containing Alertson's actual LAN IPv4
address. Save through SOPS, then commit and push only the encrypted YAML file.
Use an editor without persistent plaintext backups. Do not use a plaintext
intermediate file or put the value in command-line arguments or shell history.
The operator supplies the real address; this public repository has no fallback.

In this public configuration repository, update only the private input:

```console
nix flake update my-secrets
nix flake check --no-build
```

Review and commit `flake.lock` separately. Deploy the public configuration and
updated lock through the normal host flake. On Emilia, that flake is based on
`flakes/flake.nix`; update its `cfg` input to the public commit before rebuilding:

```console
sudo nixos-rebuild switch --flake .#emilia
```

The encrypted entry must exist in the pinned private input before the first
deployment. A missing key fails sops-nix's secret validation/installation. A
missing runtime include or malformed upstream configuration fails Nginx
validation. Nginx also accepts hostnames, so ensure the secret contains a literal
IPv4 address to avoid reintroducing DNS resolution. A failed reload preserves
Nginx's previous running configuration; check deployment status.

## Runtime behavior and privacy

SOPS decrypts `alertson-ip` and renders
`/run/secrets/rendered/grafana-upstream.conf` on Emilia. The rendered file is
root-owned and readable by the Nginx group (`0440`), because the NixOS service
runs its master and validation commands as the Nginx user. The underlying secret
retains sops-nix's root-only defaults.

The snippet defines `grafana_backend` with a literal address and port.
The Grafana vhost uses `proxy_pass http://grafana_backend` and keeps its
existing HTTPS, headers, request URI handling, and WebSocket settings.

The Nix store contains the encrypted YAML, an unexpanded SOPS placeholder
template, and an Nginx `include` path. Nix never reads the decrypted value.
Decryption and substitution happen on the deployed machine, outside evaluation
and builds, so the address is absent from generated store configurations and
build logs. Do not copy rendered files into the repository or use `nginx -T`
in public logs: that command expands runtime includes and prints the address.
Nginx runtime error logs can also contain backend addresses.

With the current activation-script mode, `setupSecrets` installs the template
before services start at boot and before service changes during a switch. If
sops-nix's systemd activation mode is enabled later, Emilia's Nginx service
explicitly requires and starts after `sops-install-secrets.service`. No DNS
service dependency is added. The template's `reloadUnits` schedules Nginx's
native validating reload only when its rendered contents change, so changing
unrelated secrets does not reload Nginx. A first configuration deployment may
restart Nginx normally; later address-only updates need only a reload.

## Verify on Emilia

After deployment:

```console
sudo stat -Lc '%U %G %a' /run/secrets/rendered/grafana-upstream.conf
sudo systemctl reload nginx
systemctl is-active nginx
curl --fail --silent --show-error https://monitor.tapirus.cc/api/health
```

Expect `root nginx 440`, a successful validating reload, an active service, and
Grafana's health response. Open Grafana and check the Live WebSocket connection
in browser developer tools.

To validate the complete deployed configuration without network/DNS access,
obtain the Nginx binary and its `-c` configuration path from:

```console
systemctl show nginx --property=ExecStart --value
```

Use those paths in this command, replacing `NGINX_BINARY` and `NGINX_CONFIG`:

```console
sudo systemd-run --wait --pipe --collect \
  -p PrivateNetwork=yes -p User=nginx -p Group=nginx \
  -p 'InaccessiblePaths=-/run/nscd -/run/systemd/resolve' \
  -p BindReadOnlyPaths=/dev/null:/etc/hosts \
  NGINX_BINARY -t -c NGINX_CONFIG
```

This tests the installed runtime snippet and certificates in a separate network
namespace, with the hosts file and host resolver sockets hidden, without
interrupting the running proxy. It should succeed with no resolution of
`alertson`. Repeat the service/health checks after the next normal reboot to
verify boot activation.

To inspect the installed address locally, read the rendered snippet with
`sudo cat /run/secrets/rendered/grafana-upstream.conf`. After a successful reload,
make a Grafana request and inspect `sudo ss -ntp '( dport = :3000 )'` while a
connection is open to confirm the address actually used by Nginx. Both commands
show private information; keep their output local. After an address update,
repeat the reload-status, health, and connection checks. Old WebSocket sessions
can retain connections to the old backend while graceful reload completes.

## Local validation results (2026-11-18)

Checked the pinned NixOS 26.05 source (`f68407657ad2`) and sops-nix
(`7c637afdccdf`) before implementation. Nginx is version 1.30.6.

- `nix flake check --no-build`: passed. This repository exports custom
  `systemTypes`, so this command alone does not evaluate Emilia.
- Evaluated `(flake.systemTypes.emilia {}).config`: verified the relevant
  Nginx startup/reload commands, secret/template permissions, and activation
  mode. Also evaluated with `sops.useSystemdActivation = true`: Nginx requires
  and starts after the installer, which precedes `sysinit-reactivation.target`.
- Built Emilia's generated `nginx.conf` derivation with its existing Gixy
  validation enabled: passed without any decrypted secret in the build.
- Ran the pinned Nginx `-t` against that complete generated configuration in
  private user, mount, and network namespaces. Used a synthetic documentation
  address and temporary certificate/runtime paths, hid nscd, and replaced hosts
  and resolver configuration. Confirmed `alertson` did not resolve: validation
  passed. Existing proxy-header hash sizing warnings were nonfatal.
- The same test rejected a missing runtime include. Address validation uses
  Nginx's normal upstream parsing; there is no separate IP-only validation block.
- `nixpkgs-fmt` and `prek run --all-files`: passed.
- `statix check`: existing repository findings remain; comparing the two changed
  Nix files with HEAD showed the same diagnostic codes and counts.

The real encrypted entry is being supplied by the operator. Live HTTPS,
deployment, and reboot checks require that entry and remain to be run on Emilia
using the commands above. No actual private address was used in these tests.
