# config

To update flake you need to use ssh-agent. Based on https://git.notthebe.ee/notthebee/nix-config

## Machine monitoring

Grafana and Prometheus run on the `alertson` VM. Grafana provisions
**Homelab → Homelab Machines Overview** at `/d/homelab-machines` with three
matrices: physical machines, Intel NUC VMs, and NAS VMs.

| Machine | Role / placement | Prometheus Node Exporter target |
| --- | --- | --- |
| NixOS desktop | Physical desktop | `desktop:9100` |
| NAS | Physical NAS | `nas:9100` |
| Intel NUC / Proxmox | Physical hypervisor | `saga:9100` |
| emilia | VM on `saga` | `emilia:9100` |
| Home Assistant OS | VM on `saga`, managed outside this repository | `homeassistant:9100` |
| alertson | VM on `nas`; hosts monitoring | `localhost:9100` |
| Proxmox Backup Server | VM on `nas` | `pbs:9100` |

Proxmox Backup Server must expose Node Exporter on `pbs:9100`, reachable
from `alertson`; its exporter installation is managed outside this repository.

Each matrix shows exporter availability, CPU usage, memory usage, the
fullest writable filesystem, and network receive/transmit rates. Usage
cells turn yellow at 75% and red at 90%. Down exporters remain visible;
unavailable metrics show `Unknown`. Filesystem usage excludes temporary
and container filesystems, and network totals exclude loopback and common
guest/container interfaces.

Click a machine name to open **Node Exporter Full** with that machine and
the same time range selected. The matrices show current resource usage;
CPU and network rates use Grafana's rate interval. The drilldown provides
the historical charts and detailed filesystem/interface metrics.

Add exporters in `modules/machines/alertson/homelab/default.nix` to the
`node` scrape job. Set `machine_type` to `physical` or `vm`, and for VMs set
`hypervisor` to `saga` or `nas`. Those labels place new targets in the
appropriate matrix automatically. Keep `availability="always-on"` for
servers and `availability="best-effort"` for the desktop.

After deploying the updated configuration to `alertson`, Grafana's file
provider loads the dashboard automatically. Dashboard changes belong in
`modules/homelab/services/monitoring/grafana/machines-overview.nix`, since
provisioning disables UI edits.

## GitHub Actions secrets

### `GH_TOKEN_FOR_UPDATES`

The [`update-flake-lock`](.github/workflows/update-flake-lock.yml) workflow uses this token to push the updated lock-file branch and open a pull request. The final merge step also uses it with `gh pr merge --admin`, so the token owner must be a repository admin.

Create the token in **User Settings → Developer settings → Personal access tokens → Fine-grained tokens** and store it in **Repository Settings tabs → Secrets and variables → Actions → Environment secrets** for the `production` environment.

#### Classic PAT (simplest)

1. Generate a new classic token.
2. Select the `repo` scope (full control of private repositories).

#### Fine-grained PAT

1. Generate a new fine-grained token.
2. Add `skiinganchor/config` to the repository access list.
3. Grant **Contents** and **Pull requests** read and write permissions.

#### `GH_PRIVATE_KEY`

An SSH private key used by [`webfactory/ssh-agent`](https://github.com/webfactory/ssh-agent) so Nix can fetch private flake inputs such as `skiinganchor/config-private` during `nix flake update`.

## GNOME Calendar with Nextcloud

The configuration provisions Nextcloud accounts declaratively through GNOME Online Accounts, which then synchronizes Calendar, Contacts, and Files through Evolution Data Server. The provisioner uses GOA's D-Bus API and never writes `accounts.conf` itself.

Create an app in `https://cloud.example.com/settings/user/security`, eg. app name `gnome-online-accounts` and save it to the sops file/key of the user.

```yaml
nextcloud:
    alice:
        app-password: something
```

Declare an account under a normal user. `sopsFile` must point to an encrypted file available during evaluation; the secret value itself is read only by Home Manager's `sops-nix.service` at runtime.

```nix
homelab.mainUser.accounts = [
  {
    serverAddress = "https://cloud.example.com";
    username = "alice";
    sopsSecretName = "nextcloud/<linux-username>/app-password";
    sopsFile = "${my-secrets}/secrets/nixos.yaml";
  }
];
```

Create the matching SOPS key with a Nextcloud app password, and ensure the user's age identity is available at `~/.config/sops/age/keys.txt` before the graphical session starts. The generated user service runs after `sops-nix.service`, checks GOA for the account first, and gives the password to GOA only when it needs to create the account. GOA stores the credential in GNOME Keyring. Do not put passwords in Nix files or Git.
