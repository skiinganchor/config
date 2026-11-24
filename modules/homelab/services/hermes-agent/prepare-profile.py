"""Publish one profile's private inputs before its Hermes processes start."""

import argparse
import base64
import contextlib
import errno
import fcntl
import hashlib
import io
import json
import logging
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import sys
import tarfile
import tempfile


def private_dir(path):
    if path.is_symlink():
        raise ValueError("Unexpected state symlink")
    path.mkdir(mode=0o700, exist_ok=True)
    path.chmod(0o700)


def hermes_state_dir(path):
    if path.is_symlink():
        if not path.is_dir():
            raise ValueError("Unavailable state directory link")
        return
    private_dir(path)


def migrate_profile_home(home, legacy_home):
    if legacy_home == home:
        return
    private_dir(home.parent)
    if legacy_home.is_symlink():
        if legacy_home.readlink() == home and home.is_dir() and not home.is_symlink():
            return
        raise ValueError("Unexpected legacy profile link")
    if legacy_home.exists():
        if home.exists() or home.is_symlink() or not legacy_home.is_dir():
            raise ValueError("Cannot migrate conflicting Hermes profile directories")
        legacy_home.rename(home)
    private_dir(home)
    legacy_home.symlink_to(home, target_is_directory=True)


def regular_bytes(path):
    if path.is_symlink():
        raise ValueError("Unexpected state symlink")
    return path.read_bytes()


def write_private(path, data):
    if path.exists() or path.is_symlink():
        if regular_bytes(path) == data:
            if path.stat().st_mode & 0o777 != 0o600:
                path.chmod(0o600)
            return
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as target:
            target.write(data)
            target.flush()
            os.fsync(target.fileno())
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def parse_object(contents):
    value = json.loads(contents)
    if not isinstance(value, dict):
        raise ValueError("Expected a JSON object")
    return value


def seed_auth(home, auth, legacy_codex):
    if auth is None and legacy_codex is None:
        return
    from hermes_cli.auth import _auth_store_lock, _load_auth_store, _save_auth_store

    target = home / "auth.json"
    with _auth_store_lock():
        if target.is_symlink():
            raise ValueError("Unexpected auth symlink")
        if auth is not None:
            if not target.exists():
                write_private(target, auth)
            return
        if target.exists():
            store = parse_object(regular_bytes(target))
            if store.get("credential_pool", {}).get("openai-codex") or store.get("providers", {}).get("openai-codex"):
                return  # The refresh token may already have rotated in this state.
        from agent.credential_pool import PooledCredential
        from hermes_cli.auth import DEFAULT_CODEX_BASE_URL, _utc_now_z

        store = _load_auth_store()
        entry = PooledCredential.from_dict("openai-codex", {
            **legacy_codex["tokens"],
            "id": legacy_codex["id"],
            "label": "openai-codex",
            "auth_type": "oauth",
            "source": "manual:device_code",
            "priority": 0,
            "base_url": legacy_codex.get("base_url", DEFAULT_CODEX_BASE_URL),
            "last_refresh": legacy_codex.get("last_refresh") or _utc_now_z(),
        }).to_dict()
        store.setdefault("credential_pool", {})["openai-codex"] = [entry]
        _save_auth_store(store)


def seed_garmin(directory, seed):
    private_dir(directory)
    marker = directory / ".nixos-token-source-sha256"
    target = directory / "garmin_tokens.json"
    digest = hashlib.sha256(seed).hexdigest().encode("ascii")
    previous = regular_bytes(marker) if marker.exists() or marker.is_symlink() else None
    if target.is_symlink():
        raise ValueError("Unexpected Garmin token symlink")
    if not target.exists() or (previous is not None and previous != digest):
        write_private(target, seed)
    elif target.stat().st_mode & 0o777 != 0o600:
        target.chmod(0o600)
    write_private(marker, digest)


PROVIDER_ENV = {
    "opencode-go": ("OPENCODE_GO_API_KEY", "OPENCODE_GO_BASE_URL"),
    "zai": ("GLM_API_KEY", "GLM_BASE_URL"),
}


def apply_legacy_providers(config, bindings, source):
    """Translate existing private declarations without reconciling Hermes's pool."""
    declarations = json.loads(source.read_bytes())
    if not isinstance(declarations, list) or not declarations:
        raise ValueError("Expected legacy providers")
    environment = {}
    codex = None
    seen = set()
    for declaration in declarations:
        provider = declaration["provider"]
        if provider in seen or not isinstance(declaration["model"], str) or not declaration["model"].strip():
            raise ValueError("Invalid legacy provider")
        seen.add(provider)
        if provider == "openai-codex":
            codex = declaration
            if not all(isinstance(codex["tokens"][key], str) and codex["tokens"][key]
                       for key in ("access_token", "refresh_token")) or not codex["id"]:
                raise ValueError("Invalid legacy OAuth seed")
        else:
            key_name, url_name = PROVIDER_ENV[provider]
            if not isinstance(declaration["api_key"], str) or not declaration["api_key"].strip():
                raise ValueError("Invalid legacy provider key")
            environment[key_name] = declaration["api_key"]
            if declaration.get("base_url"):
                environment[url_name] = declaration["base_url"]
    managed = {name for names in PROVIDER_ENV.values() for name in names} | {"ZAI_API_KEY", "Z_AI_API_KEY"}
    dotenv = "".join(binding.original.string for binding in bindings if binding.key not in managed)
    for key, value in environment.items():
        quoted = value.replace("\\", "\\\\").replace("'", "\\'")
        dotenv += f"\n{key}='{quoted}'"
    first = declarations[0]
    model = config.setdefault("model", {})
    for key in ("base_url", "api_key", "key_env", "api_mode"):
        model.pop(key, None)
    model.update(provider=first["provider"], default=first["model"])
    return (dotenv + "\n").encode(), codex


def skill_archive(home, data):
    """Install ordinary files only, then atomically switch the discovery root."""
    store = home / ".managed-skill-generations"
    private_dir(store)
    link = home / "managed-skills"
    digest = hashlib.sha256(data).hexdigest()
    generation = store / digest
    previous = None
    if link.is_symlink():
        previous = Path(os.readlink(link))
        if previous.parent.resolve() != store.resolve() or not re.fullmatch(r"[0-9a-f]{64}", previous.name) or previous.is_symlink():
            raise ValueError("Unexpected managed skills target")
    elif link.exists():
        raise ValueError("Managed skills path already in use")
    if generation.is_symlink():
        raise ValueError("Unexpected managed skills generation")
    if not generation.is_dir():
        with tempfile.TemporaryDirectory(dir=store) as staging:
            staged = Path(staging) / "tree"
            staged.mkdir(mode=0o700)
            with tarfile.open(fileobj=io.BytesIO(data), mode="r:*") as archive:
                paths = set()
                for member in archive:
                    relative = PurePosixPath(member.name)
                    if relative.is_absolute() or ".." in relative.parts or relative in paths:
                        raise ValueError("Invalid archive path")
                    paths.add(relative)
                    target = staged.joinpath(*relative.parts)
                    if member.isdir():
                        target.mkdir(parents=True, exist_ok=True)
                    elif member.isfile() and relative.parts:
                        target.parent.mkdir(parents=True, exist_ok=True)
                        with archive.extractfile(member) as source, target.open("xb") as destination:
                            shutil.copyfileobj(source, destination)
                        target.chmod(0o700 if member.mode & 0o111 else 0o600)
                    else:
                        raise ValueError("Unsupported archive member")
            os.replace(staged, generation)
    if previous != generation:
        with tempfile.TemporaryDirectory(dir=store) as staging:
            pointer = Path(staging) / "pointer"
            pointer.symlink_to(generation)
            os.replace(pointer, link)
        if previous is not None and previous.is_dir():
            shutil.rmtree(previous)


def publish_skills(home, archive, legacy):
    if archive is not None:
        skill_archive(home, archive)
        marker = home / ".nixos-skills/categories"
        if marker.is_file() and marker.read_bytes().strip() != b"[]":
            # Empty the old managed categories only. The compatibility adapter
            # restores unmanaged entries it previously adopted in those categories.
            import legacy_skills

            with tempfile.NamedTemporaryFile(dir=home) as empty:
                empty.write(b"[]")
                empty.flush()
                legacy_skills.reconcile(empty.name, home)
    elif legacy is not None:
        import legacy_skills

        legacy_skills.reconcile(legacy, home)


def prepare(args):
    from dotenv.parser import parse_stream
    from hermes_yaml import safe_dump, safe_load

    home = Path(os.environ["HERMES_HOME"])
    state_directory = args.state_directory or home.parent
    args.phase = "opening profile state"
    private_dir(home)
    lock = home / ".profile-prepare.lock"
    with os.fdopen(os.open(lock, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600), "r+b") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        args.phase = "reading and validating private inputs"
        config_data = args.config.read_bytes()
        config = safe_load(config_data)
        env_data = args.env.read_bytes()
        bindings = list(parse_stream(io.StringIO(env_data.decode("utf-8-sig"))))
        if not isinstance(config, dict) or any(binding.error for binding in bindings):
            raise ValueError("Expected a Hermes YAML mapping and native dotenv")
        auth_data = args.auth.read_bytes() if args.auth else None
        garmin_data = args.garmin.read_bytes() if args.garmin else None
        archive = None
        if args.skills_base64:
            encoded = b"".join(args.skills_base64.read_bytes().split())
            archive = base64.b64decode(encoded, validate=True)
        for seed in (auth_data, garmin_data):
            if seed is not None:
                parse_object(seed)

        codex = None
        if args.legacyProviders:
            env_data, codex = apply_legacy_providers(config, bindings, args.legacyProviders)
            config_data = safe_dump(config, sort_keys=False).encode()
        elif args.model and "model" not in config:
            model = safe_load(args.model.read_bytes())
            if (not isinstance(model, dict) or model.keys() != {"provider", "default"}
                    or not all(isinstance(value, str) and value.strip() for value in model.values())):
                raise ValueError("Expected shared model routing with provider and default")
            config["model"] = model
            config_data = safe_dump(config, sort_keys=False).encode()

        cron = None
        if args.cron:
            import reconcile_cron

            cron = reconcile_cron.read_declarations(args.cron)
        args.phase = "writing profile state"
        for directory in ("cron", "sessions", "logs", "memories"):
            hermes_state_dir(home / directory)
        private_dir(state_directory / "workspace")
        publish_skills(home, archive, args.legacySkills)
        seed_auth(home, auth_data, codex)
        if garmin_data is not None:
            seed_garmin(state_directory / ".garminconnect", garmin_data)
        write_private(home / ".managed", b"nixos\n")
        write_private(home / ".env", env_data)
        write_private(home / "config.yaml", config_data)
        if cron is not None:
            args.phase = "reconciling cron jobs"
            from hermes_cli.env_loader import load_hermes_dotenv
            from hermes_time import reset_cache

            load_hermes_dotenv(hermes_home=home, load_external_secrets=False)
            reset_cache()
            reconcile_cron.reconcile(cron)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--state-directory", type=Path)
    parser.add_argument("--migrate-only", action="store_true")
    for name in ("config", "env"):
        parser.add_argument(f"--{name}", type=Path)
    for name in ("auth", "garmin", "skills-base64", "cron", "legacyProviders", "legacySkills", "model"):
        parser.add_argument(f"--{name}", type=Path)
    args = parser.parse_args()
    if args.migrate_only and args.state_directory is None:
        parser.error("--migrate-only requires --state-directory")
    if not args.migrate_only and (args.config is None or args.env is None):
        parser.error("preparation requires --config and --env")
    os.umask(0o077)
    logging.disable(logging.CRITICAL)
    home = Path(os.environ["HERMES_HOME"])
    args.phase = "loading preparation dependencies"
    try:
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            if args.migrate_only:
                args.phase = "moving the legacy profile home"
                migrate_profile_home(home, args.state_directory / ".hermes")
            else:
                prepare(args)
    except Exception as exc:
        detail = errno.errorcode.get(exc.errno) if isinstance(exc, OSError) else None
        print(f"Hermes profile {home}: failed while {args.phase} ({detail or type(exc).__name__}).",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
