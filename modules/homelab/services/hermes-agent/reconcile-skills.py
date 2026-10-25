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
    if not isinstance(value, list):
        raise ValueError("Expected a list")

    grouped = {}
    seen_names = set()
    for declaration in value:
        if not isinstance(declaration, dict) or set(declaration) != {"name", "category", "files"}:
            raise ValueError("Invalid skill fields")
        name = declaration["name"]
        category = declaration["category"]
        if not valid_category(category):
            raise ValueError("Invalid skill category")
        if not isinstance(name, str) or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name):
            raise ValueError("Invalid skill name")
        if name in seen_names:
            raise ValueError("Duplicate skill name")
        seen_names.add(name)
        grouped.setdefault(category, {})[name] = declaration["files"]
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


def copy_unmanaged_entries(source, destination, excluded_names):
    """Copy an existing category into a new generation without following symlinks."""
    def copy_entry(entry, target):
        if entry.is_symlink():
            raise ValueError("Unexpected symlink in existing category")
        if entry.is_dir():
            target.mkdir(mode=0o700)
            for child in entry.iterdir():
                copy_entry(child, target / child.name)
            target.chmod(0o700)
        elif entry.is_file():
            shutil.copyfile(entry, target)
            target.chmod(0o700 if entry.stat().st_mode & 0o111 else 0o600)
        else:
            raise ValueError("Unexpected file type in existing category")

    for entry in source.iterdir():
        if entry.name not in excluded_names:
            copy_entry(entry, destination / entry.name)


def remove_tree(path, ignore_errors=False):
    """Make owned directories removable, then delete a managed runtime tree."""
    try:
        if path.is_symlink():
            path.unlink()
            return
        path.chmod(0o700)
        for root, directories, _ in os.walk(path, topdown=True):
            Path(root).chmod(0o700)
            for name in directories:
                child = Path(root) / name
                if not child.is_symlink():
                    child.chmod(0o700)
        shutil.rmtree(path)
    except OSError:
        if not ignore_errors:
            raise


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
            elif target.exists() and not target.is_dir():
                raise ValueError("Category namespace is not a directory")

        generations = {}
        backups = {}
        old_links = {}
        changed_categories = []
        removed_links = {}
        preserved_categories = {}
        preserved_dirs = []
        committed = False
        try:
            for category, declarations in grouped.items():
                generation = Path(tempfile.mkdtemp(prefix="generation-", dir=store))
                generations[category] = generation

                target = skills / category
                excluded_names = set(declarations)
                if target.is_symlink():
                    old_generation = old_generations[category]
                    manifest = store / f"{old_generation.name}.skills.json"
                    if manifest.is_file() and not manifest.is_symlink():
                        managed_names = json.loads(manifest.read_text(encoding="utf-8"))
                        if (not isinstance(managed_names, list)
                                or any(not isinstance(name, str)
                                       or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name)
                                       for name in managed_names)):
                            raise ValueError("Invalid managed skill manifest")
                        excluded_names.update(managed_names)
                    else:
                        # Earlier generations held only declared skills.
                        excluded_names.update(entry.name for entry in old_generation.iterdir())
                    copy_unmanaged_entries(old_generation, generation, excluded_names)
                elif target.is_dir():
                    # Keep unrelated skills and files already present in this category.
                    copy_unmanaged_entries(target, generation, excluded_names)

                for name, files in declarations.items():
                    directory = generation / name
                    directory.mkdir(mode=0o700)
                    for filename, content in files.items():
                        destination = directory / filename
                        destination.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
                        destination.write_text(content, encoding="utf-8")
                        destination.chmod(0o700 if filename.startswith("scripts/") else 0o600)
                (store / f"{generation.name}.skills.json").write_text(
                    json.dumps(sorted(declarations)), encoding="utf-8")

            for category in previous_categories - set(grouped):
                target = skills / category
                if not target.is_symlink():
                    continue
                old_generation = old_generations[category]
                manifest = store / f"{old_generation.name}.skills.json"
                if manifest.is_file() and not manifest.is_symlink():
                    managed_names = json.loads(manifest.read_text(encoding="utf-8"))
                    if (not isinstance(managed_names, list)
                            or any(not isinstance(name, str)
                                   or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name)
                                   for name in managed_names)):
                        raise ValueError("Invalid managed skill manifest")
                    excluded_names = set(managed_names)
                else:
                    # Earlier generations held only declared skills.
                    excluded_names = {entry.name for entry in old_generation.iterdir()}
                preserved = Path(tempfile.mkdtemp(prefix="preserved-", dir=store))
                preserved_dirs.append(preserved)
                copy_unmanaged_entries(old_generation, preserved, excluded_names)
                if any(preserved.iterdir()):
                    preserved_categories[category] = preserved

            for category, generation in generations.items():
                target = skills / category
                if target.is_symlink():
                    old_links[category] = os.readlink(target)
                elif target.exists():
                    backup = Path(tempfile.mkdtemp(prefix="backup-", dir=store))
                    backup.rmdir()
                    os.replace(target, backup)
                    backups[category] = backup
                changed_categories.append(category)
                link = store / f"pending-{category}"
                link.unlink(missing_ok=True)
                link.symlink_to(generation)
                os.replace(link, target)

            for category in previous_categories - set(grouped):
                target = skills / category
                if target.is_symlink():
                    removed_links[category] = os.readlink(target)
                    target.unlink()
                    if category in preserved_categories:
                        os.replace(preserved_categories[category], target)

            category_temp = store / "categories.pending"
            category_temp.write_text(json.dumps(sorted(grouped)), encoding="utf-8")
            os.replace(category_temp, category_file)
            committed = True
        except Exception:
            for category in reversed(changed_categories):
                target = skills / category
                target.unlink(missing_ok=True)
                if category in backups:
                    os.replace(backups[category], target)
                elif category in old_links:
                    link = store / f"restore-{category}"
                    link.unlink(missing_ok=True)
                    link.symlink_to(old_links[category])
                    os.replace(link, target)
            for category, old_target in removed_links.items():
                if category in preserved_categories:
                    shutil.rmtree(skills / category, ignore_errors=True)
                link = store / f"restore-{category}"
                link.unlink(missing_ok=True)
                link.symlink_to(old_target)
                os.replace(link, skills / category)
            raise
        finally:
            for link in store.glob("pending-*"):
                link.unlink(missing_ok=True)
            for preserved in preserved_dirs:
                if preserved.exists():
                    remove_tree(preserved, ignore_errors=True)
            if not committed:
                for generation in generations.values():
                    remove_tree(generation, ignore_errors=True)
                    (store / f"{generation.name}.skills.json").unlink(missing_ok=True)
        for backup in backups.values():
            remove_tree(backup, ignore_errors=True)
        # Remove superseded generations only after all category links are published.
        for category, generation in old_generations.items():
            if generation not in generations.values() and generation.exists():
                remove_tree(generation)
                (store / f"{generation.name}.skills.json").unlink(missing_ok=True)


def main():
    os.umask(0o077)
    try:
        reconcile(sys.argv[1], Path(os.environ["HERMES_HOME"]).absolute())
    except json.JSONDecodeError as error:
        print(f"Hermes skill reconciliation failed: invalid JSON at line {error.lineno}, column {error.colno}.",
              file=sys.stderr)
        return 1
    except UnicodeError:
        print("Hermes skill reconciliation failed: the skills file is not valid UTF-8.",
              file=sys.stderr)
        return 1
    except ValueError as error:
        # Validation errors use fixed messages and never include declaration data.
        print(f"Hermes skill reconciliation failed: {error}", file=sys.stderr)
        return 1
    except OSError as error:
        # strerror is a generic OS message; avoid filenames and file contents.
        reason = error.strerror or type(error).__name__
        print(f"Hermes skill reconciliation failed: runtime file error ({reason}).",
              file=sys.stderr)
        return 1
    except Exception as error:
        # Do not expose filenames, skill contents, or JSON excerpts to journald.
        print(f"Hermes skill reconciliation failed: unexpected {type(error).__name__}.",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
