# Aurral filesystem isolation on Emilia

Aurral runs as `aurral:aurral` (UID and GID `1201:1201`). The service adds
`users` (GID `100`) to read the existing NFS collection and work with slskd's
completed downloads. That group can also write to the curated library at the
NFS layer. Landlock removes that write access for Aurral and its descendants
without requiring QNAP account or ACL changes.

Systemd's `ReadOnlyPaths` setup previously failed with `226/NAMESPACE` because
root squashing prevented the mount namespace setup from traversing the NFS
paths. The current unit waits for the NFS mount and orders startup after slskd,
which creates the completed-download directory. After systemd switches to the
Aurral identity, the launcher applies Landlock and executes the original
`catatonit -- aurral` command. Catatonit stays PID 1 in the private PID
namespace and supervises Aurral and its workers. Landrun 0.1.15 requires
Landlock ABI 5 and aborts startup if it cannot apply the policy.

| Path | Landlock access |
| --- | --- |
| `/mnt/media/music` and `/mnt/media/music/library` | Read-only, with the two writable subtrees below |
| `/mnt/media/music/aurral` and `/mnt/media/music/import` | Read/write |
| `/var/lib/aurral` and the unit's private `/tmp` | Read/write |
| `/nix/store` | Read/execute |
| `/dev/null` | Read/write |
| `/dev/urandom`, the unit's restricted `/proc`, and named DNS, NSS, TLS, and timezone files | Read-only |
| Systemd's `CREDENTIALS_DIRECTORY`, when supplied | Read-only |

The launcher uses the Nix store's `env -0` to enumerate exported variables
and passes only their names to `landrun --env`. Landrun reads each value from
its inherited environment. This preserves variables from systemd's
`EnvironmentFile`, including empty values and values containing whitespace,
without putting secret values in command-line arguments. Network access stays
available to Aurral, slskd, Lidarr, and metadata providers.

Before switching generations, record the current generation and the curated
track count. For a consistent state backup, stop Aurral and archive
`/var/lib/aurral` with its ownership and permissions intact. If the switch
fails, roll back to the recorded generation and keep the state archive.

## Service health after activation

Run on Emilia.

```bash
systemctl status aurral.service --no-pager
systemctl show aurral.service \
  -p User -p Group -p SupplementaryGroups -p ExecStart
curl -fsS http://127.0.0.1:3001/api/health/live

systemctl show aurral.service -p ActiveState -p SubState -p NRestarts
sudo journalctl -u aurral.service --since "5 minutes ago" --no-pager
```

Expect `User=aurral`, `Group=aurral`, `SupplementaryGroups=users`, and
`{"status":"ok"}` from the health endpoint. Repeat the health and restart
checks after a few minutes. Expect `ActiveState=active`, `SubState=running`,
a stable restart count, and no new startup errors.

In Aurral, check that the existing database, settings, history, indexed music,
and Lidarr plugin load. Play a known curated track and verify that a scan can
read the curated library. To verify the acquisition routes, approve a single
track downloaded through slskd and check that Aurral moves it into its own
library. Send a full album through the Lidarr plugin and verify that Lidarr
imports it into the curated library.

## Test the deployed Landlock policy

Run this from Bash on Emilia. It finds the launcher from the effective unit
and runs the same policy in a transient service with Aurral's identity. The
probe uses scratch directories created by `share` and cleans them up on exit.
The two unsandboxed `test -w` checks establish that the probe can distinguish
Landlock denials from NFS permissions.

```bash
(
  set -euo pipefail
  wrapper=$(systemctl show aurral.service -p ExecStart --value |
    sed -nE 's|^\{ path=(/nix/store/[^ ;]+-aurral-landlock) ;.*|\1|p')
  test -x "$wrapper"

  probes=()
  cleanup() {
    if (( ${#probes[@]} )); then
      sudo -u share rm -rf -- "${probes[@]}"
    fi
  }
  trap cleanup EXIT

  for tree in library aurral import; do
    probe=$(sudo -u share mktemp -d "/mnt/media/music/$tree/.aurral-landlock-probe.XXXXXXXX")
    probes+=("$probe")
    sudo -u share chmod 0770 "$probe"
  done
  sudo -u share bash -c 'umask 0007; printf "curated probe\n" > "$1"' bash "${probes[0]}/curated"
  sudo -u share chmod 0660 "${probes[0]}/curated"
  sudo setpriv --reuid 1201 --regid 1201 --groups 100 -- test -w "${probes[0]}"
  sudo setpriv --reuid 1201 --regid 1201 --groups 100 -- test -w "${probes[0]}/curated"

  sudo systemd-run --quiet --wait --pipe --collect \
    -p User=aurral -p Group=aurral -p SupplementaryGroups=users \
    -p PrivateTmp=yes -p PrivatePIDs=yes -p ProtectProc=invisible -p ProcSubset=pid \
    -p WorkingDirectory=/var/lib/aurral -p UMask=0007 \
    --setenv=PATH=/run/current-system/sw/bin \
    "$wrapper" /run/current-system/sw/bin/bash -s -- "${probes[@]}" <<'PROBE'
set -euo pipefail
library=$1
downloads=$2
import=$3

deny() {
  if "$@"; then
    printf 'Unexpected success: %s\n' "$1" >&2
    exit 1
  fi
}

test "$(cat "$library/curated")" = 'curated probe'
deny touch "$library/new"
deny bash -c 'printf x >> "$1"' bash "$library/curated"
deny mv -- "$library/curated" "$library/renamed"
deny rm -- "$library/curated"
test -f "$library/curated"

printf probe > "$downloads/new"
mv -- "$downloads/new" "$downloads/renamed"
rm -- "$downloads/renamed"

mkdir -- "$import/completed"
printf probe > "$import/completed/track"
mv -- "$import/completed/track" "$import/completed/renamed"
mv -- "$import/completed/renamed" "$downloads/imported"
rmdir -- "$import/completed"
test "$(cat "$downloads/imported")" = probe
rm -- "$downloads/imported"
printf 'Landlock probe passed\n'
PROBE
)
```

Expect permission errors for the four curated-library writes and
`Landlock probe passed` at the end. Every attempted write targets the scratch
directories or files created for this probe.
