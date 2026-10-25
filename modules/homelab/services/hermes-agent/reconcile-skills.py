"""Publish private skills in a managed Hermes category namespace."""

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


def valid_category(category):
    return isinstance(category, str) and re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", category)


def parse_declarations(value):
    # Support the original skills-only object and the intermediate one-category format.
    if isinstance(value, dict) and "category" in value and "skills" in value:
        category = value["category"]
        if not valid_category(category):
            raise ValueError("Invalid skill category")
        grouped = {category: value["skills"]}
    elif isinstance(value, dict) and "skills" in value:
        grouped = {}
        for name, declaration in value["skills"].items():
            if not isinstance(declaration, dict):
                raise ValueError("Expected skill object")
            category = declaration.get("category")
            files = declaration.get("files")
            if not valid_category(category):
                raise ValueError("Invalid skill category")
            grouped.setdefault(category, {})[name] = files
    else:
        grouped = {"nixos": value}
    for declarations in grouped.values():
        validate(declarations)
    return grouped


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
        grouped = parse_declarations(json.load(stream, object_pairs_hook=unique_object))

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
        category_file = store / "categories"
        previous_categories = {"nixos"}
        if category_file.exists():
            marker = category_file.read_text(encoding="utf-8")
            try:
                parsed_marker = json.loads(marker)
                previous_categories = set(parsed_marker)
            except json.JSONDecodeError:
                # Migrate the single-category marker written by the earlier version.
                previous_categories = {marker}
            if not all(valid_category(item) for item in previous_categories):
                raise ValueError("Unexpected managed category")

        old_generations = {}
        for category in previous_categories | set(grouped):
            target = skills / category
            if target.is_symlink():
                generation = Path(os.readlink(target))
                if (generation.parent != store
                        or not generation.name.startswith("generation-")
                        or generation.is_symlink()):
                    raise ValueError("Unexpected namespace target")
                old_generations[category] = generation
            elif target.exists():
                raise ValueError("Namespace already exists")

        generations = {}
        try:
            for category, declarations in grouped.items():
                generation = Path(tempfile.mkdtemp(prefix="generation-", dir=store))
                generations[category] = generation
                for name, files in declarations.items():
                    directory = generation / name
                    directory.mkdir(mode=0o700)
                    for filename, content in files.items():
                        destination = directory / filename
                        destination.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
                        destination.write_text(content, encoding="utf-8")
                        destination.chmod(0o700 if filename.startswith("scripts/") else 0o600)

            for category, generation in generations.items():
                link = store / f"pending-{category}"
                link.unlink(missing_ok=True)
                link.symlink_to(generation)
                os.replace(link, skills / category)

            for category in previous_categories - set(grouped):
                (skills / category).unlink(missing_ok=True)

            category_temp = store / "categories.pending"
            category_temp.write_text(json.dumps(sorted(grouped)), encoding="utf-8")
            os.replace(category_temp, category_file)
        finally:
            for link in store.glob("pending-*"):
                link.unlink(missing_ok=True)
            if not category_file.exists() or set(grouped) != set(json.loads(category_file.read_text(encoding="utf-8"))):
                for generation in generations.values():
                    shutil.rmtree(generation, ignore_errors=True)
        # Remove superseded generations only after all category links are published.
        for category, generation in old_generations.items():
            if generation not in generations.values() and generation.exists():
                shutil.rmtree(generation)


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
