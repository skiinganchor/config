"""Publish private skills in Hermes's reserved skills/nixos namespace."""

import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate key")
        result[key] = value
    return result


def validate(declarations):
    if not isinstance(declarations, dict):
        raise ValueError("Expected an object")
    for name, files in declarations.items():
        if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name):
            raise ValueError("Invalid skill name")
        if not isinstance(files, dict) or not files.get("SKILL.md"):
            raise ValueError("Expected SKILL.md")
        for filename, content in files.items():
            parts = filename.split("/")
            if any(part in {"", ".", ".."} for part in parts) or "\x00" in filename:
                raise ValueError("Invalid relative filename")
            if not isinstance(content, str):
                raise ValueError("Expected text content")
            # Reject file/directory collisions before changing runtime state.
            if any("/".join(parts[:i]) in files for i in range(1, len(parts))):
                raise ValueError("Conflicting paths")
            if filename != "SKILL.md" and parts[-1] == "SKILL.md":
                raise ValueError("Nested skills are not supported")


def reconcile(source, home):
    with open(source, encoding="utf-8") as stream:
        declarations = json.load(stream, object_pairs_hook=unique_object)
    validate(declarations)

    skills = home / "skills"
    store = home / ".nixos-skills"
    # Never follow a replaced state directory outside HERMES_HOME.
    if skills.is_symlink() or store.is_symlink():
        raise ValueError("Unexpected state symlink")
    skills.mkdir(mode=0o700, parents=True, exist_ok=True)
    store.mkdir(mode=0o700, exist_ok=True)
    store.chmod(0o700)
    with (store / "lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        target = skills / "nixos"
        old = None
        if target.is_symlink():
            old = Path(os.readlink(target))
            if old.parent != store or not old.name.startswith("generation-") or old.is_symlink():
                raise ValueError("Unexpected namespace target")
        elif target.exists():
            raise ValueError("Namespace already exists")

        generation = Path(tempfile.mkdtemp(prefix="generation-", dir=store))
        link = store / "pending"
        try:
            for name, files in declarations.items():
                directory = generation / name
                directory.mkdir(mode=0o700)
                for filename, content in files.items():
                    destination = directory / filename
                    destination.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
                    destination.write_text(content, encoding="utf-8")
                    destination.chmod(0o700 if filename.startswith("scripts/") else 0o600)
            link.unlink(missing_ok=True)
            link.symlink_to(generation)
            os.replace(link, target)
        finally:
            link.unlink(missing_ok=True)
            if not target.is_symlink() or Path(os.readlink(target)) != generation:
                shutil.rmtree(generation)
        # Only remove our previous generation after publishing the complete tree.
        if old is not None and old.exists():
            shutil.rmtree(old)


def main():
    os.umask(0o077)
    try:
        reconcile(sys.argv[1], Path(os.environ["HERMES_HOME"]).absolute())
    except Exception:
        # Do not expose filenames, skill contents, or JSON excerpts to journald.
        print("Hermes skill reconciliation failed; check the private skills file and runtime state.",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
