"""Seed Garmin tokens and apply intentional changes to the declared secret."""

import fcntl
import hashlib
import os
from pathlib import Path
import sys
import tempfile


def write_atomic(path, contents):
    fd, name = tempfile.mkstemp(dir=path.parent, prefix=".garmin-setup-")
    try:
        with os.fdopen(fd, "wb") as file:
            file.write(contents)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def reconcile(secret_path, token_dir):
    token_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(token_dir, 0o700)
    # Both the gateway and backend may start concurrently.
    with (token_dir / ".nixos-token-lock").open("a") as lock:
        os.chmod(lock.name, 0o600)
        fcntl.flock(lock, fcntl.LOCK_EX)
        secret = secret_path.read_bytes()
        digest = hashlib.sha256(secret).hexdigest().encode("ascii")
        marker = token_dir / ".nixos-token-source-sha256"
        token = token_dir / "garmin_tokens.json"
        previous = marker.read_bytes() if marker.exists() else None
        # On first upgrade, adopt any existing runtime token. An operator can
        # subsequently change the SOPS secret to install a replacement.
        if not token.exists() or (previous is not None and previous != digest):
            write_atomic(token, secret)
        if previous != digest:
            write_atomic(marker, digest)


if __name__ == "__main__":
    os.umask(0o077)
    reconcile(Path(sys.argv[1]), Path(sys.argv[2]))
