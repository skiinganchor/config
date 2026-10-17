"""Install private provider declarations using the pinned Hermes auth store."""

import contextlib
import hashlib
import io
import json
import logging
import os
import sys
import tempfile
from urllib.parse import urlparse


PROVIDERS = {"openai-codex", "opencode-go", "zai"}
ROUTING_FIELDS = {"provider", "default", "base_url", "api_key", "key_env", "api_mode"}
ENV_KEYS = {
    "opencode-go": ("OPENCODE_GO_API_KEY", "OPENCODE_GO_BASE_URL"),
    "zai": ("GLM_API_KEY", "GLM_BASE_URL"),
}
MANAGED_ENV = {key for keys in ENV_KEYS.values() for key in keys} | {
    "ZAI_API_KEY", "Z_AI_API_KEY",
}
SEED_MARKER = "nixos_provider_seed_sha256"


def nonempty(value):
    return isinstance(value, str) and bool(value.strip())


def declarations_from(path):
    with open(path, encoding="utf-8") as source:
        declarations = json.load(source)
    if not isinstance(declarations, list) or not declarations:
        raise ValueError("Expected a nonempty provider list")
    seen = set()
    for entry in declarations:
        if not isinstance(entry, dict):
            raise ValueError("Expected a provider object")
        provider = entry.get("provider")
        if not isinstance(provider, str) or provider not in PROVIDERS or provider in seen:
            raise ValueError("Unsupported or duplicate provider")
        seen.add(provider)
        required = {"provider", "model", "id", "tokens" if provider == "openai-codex" else "api_key"}
        optional = {"base_url"}
        if provider == "openai-codex":
            optional.add("last_refresh")
        if not required <= entry.keys() or entry.keys() - required - optional:
            raise ValueError("Invalid provider fields")
        if not nonempty(entry["id"]):
            raise ValueError("Expected a credential id")
        if "base_url" in entry:
            url = urlparse(entry["base_url"]) if nonempty(entry["base_url"]) else None
            if url is None or url.scheme != "https" or not url.hostname or url.username or url.password:
                raise ValueError("Expected an HTTPS provider URL")
        if not nonempty(entry["model"]):
            raise ValueError("Expected a model")
        # Model IDs are native IDs, not provider/model strings: Hermes receives
        # the provider explicitly, including when switching between providers.
        if any(entry["model"].startswith(f"{name}/") for name in PROVIDERS):
            raise ValueError("Expected an unprefixed model ID")
        if provider == "openai-codex":
            tokens = entry["tokens"]
            if not isinstance(tokens, dict) or any(
                not nonempty(tokens.get(key)) for key in ("access_token", "refresh_token")
            ):
                raise ValueError("Expected an OAuth access/refresh token pair")
            if tokens.keys() != {"access_token", "refresh_token"}:
                raise ValueError("Expected only access_token and refresh_token")
            if "last_refresh" in entry and not nonempty(entry["last_refresh"]):
                raise ValueError("Expected last_refresh")
        else:
            if not nonempty(entry["api_key"]):
                raise ValueError("Expected an API key")
    return declarations


def credential_from(entry, existing, legacy):
    from agent.credential_persistence import fingerprint_secret_value
    from agent.credential_pool import PooledCredential
    from hermes_cli.auth import DEFAULT_CODEX_BASE_URL, PROVIDER_REGISTRY, _utc_now_z

    provider = entry["provider"]
    if provider == "openai-codex":
        seed = hashlib.sha256(json.dumps(entry["tokens"], sort_keys=True).encode()).hexdigest()
        marker = existing.get(SEED_MARKER, legacy.get(SEED_MARKER))
        reusable = marker in (None, seed) and all(
            nonempty(existing.get(key)) for key in ("access_token", "refresh_token")
        )
        payload = dict(existing) if reusable else {}
        if not reusable:
            # Migrate the old singleton without replaying the SOPS refresh token
            # when Hermes has already rotated that same declared grant.
            tokens = legacy.get("tokens", {})
            if legacy.get(SEED_MARKER) != seed or not all(
                nonempty(tokens.get(key)) for key in ("access_token", "refresh_token")
            ):
                tokens = entry["tokens"]
                last_refresh = entry.get("last_refresh", _utc_now_z())
            else:
                last_refresh = legacy.get("last_refresh", _utc_now_z())
            payload.update(tokens, last_refresh=last_refresh)
        payload.update(auth_type="oauth", source="manual:device_code")
        payload[SEED_MARKER] = seed
        base_url = entry.get("base_url", DEFAULT_CODEX_BASE_URL)
        label = existing.get("label") or provider
    else:
        key_var, _ = ENV_KEYS[provider]
        fingerprint = fingerprint_secret_value(entry["api_key"])
        reusable = existing.get("secret_fingerprint") == fingerprint
        payload = dict(existing) if reusable else {}
        payload.update(auth_type="api_key", source=f"env:{key_var}", access_token=entry["api_key"])
        # Endpoint probing belongs to Hermes at runtime, outside this auth lock.
        base_url = entry.get("base_url", PROVIDER_REGISTRY[provider].inference_base_url)
        label = key_var
    payload.update(id=entry["id"], label=label, priority=0, base_url=base_url)
    # Native serialization supplies status/counter fields and replaces borrowed
    # environment secrets with a reference and fingerprint at the disk boundary.
    return PooledCredential.from_dict(provider, payload).to_dict()


def atomic_write(path, content):
    # Never expose a partially written credential/config file, even to another
    # Hermes process. mkstemp creates the file with mode 0600 before writing.
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as target:
            target.write(content)
            target.flush()
            os.fsync(target.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def reconcile(path, environment_path):
    # Validate all declarations before importing Hermes (which loads .env) or
    # modifying state. Errors must never include input values in the journal.
    declarations = declarations_from(path)

    import yaml
    from dotenv import dotenv_values
    from hermes_cli.auth import _auth_store_lock, _load_auth_store, _save_auth_store
    from hermes_constants import get_hermes_home

    home = get_hermes_home()
    config_path = home / "config.yaml"
    with _auth_store_lock():
        with config_path.open(encoding="utf-8") as source:
            config = yaml.safe_load(source)
        if not isinstance(config, dict) or not isinstance(config.get("model", {}), dict):
            raise ValueError("Expected a model mapping")
        # Preserve integration settings, including any upstream Nix environment,
        # and pick up SOPS rotations before restarting either service.
        environment = dict(dotenv_values(home / ".env", interpolate=False))
        environment.update(dotenv_values(environment_path, interpolate=False))
        environment = {key: value for key, value in environment.items() if key not in MANAGED_ENV}
        store = _load_auth_store()
        states = store.setdefault("providers", {})
        pools = store.setdefault("credential_pool", {})
        desired = {entry["provider"]: entry for entry in declarations}
        for provider in PROVIDERS:
            # Declarative credentials supersede interactive removal markers.
            store.get("suppressed_sources", {}).pop(provider, None)
            if provider not in desired:
                states.pop(provider, None)
                pools.pop(provider, None)
                continue
            entry = desired[provider]
            pool = pools.get(provider, [])
            if not isinstance(pool, list):
                raise ValueError("Expected a credential-pool list")
            existing = next((row for row in pool if isinstance(row, dict)
                             and row.get("id") == entry["id"]), {})
            pools[provider] = [credential_from(entry, existing, states.get(provider, {}))]
            # Pool entries own these credentials. A singleton would seed a
            # second device_code row containing the same rotating OAuth grant.
            states.pop(provider, None)
            if provider in ENV_KEYS:
                key_var, url_var = ENV_KEYS[provider]
                environment[key_var] = entry["api_key"]
                if "base_url" in entry:
                    environment[url_var] = entry["base_url"]

        first = declarations[0]
        model = config.setdefault("model", {})
        for key in ROUTING_FIELDS:
            model.pop(key, None)
        model.update(provider=first["provider"], default=first["model"])
        store["active_provider"] = first["provider"]

        def quote(value):
            return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"

        env_text = "".join(
            f"{key}={quote(value)}\n" if value is not None else f"{key}\n"
            for key, value in environment.items()
        )
        config_text = yaml.safe_dump(config, sort_keys=False)
        # Model selection is committed last, after its credentials are present.
        _save_auth_store(store)
        atomic_write(home / ".env", env_text)
        atomic_write(config_path, config_text)


def main():
    os.umask(0o077)
    logging.disable(logging.CRITICAL)
    try:
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            reconcile(sys.argv[1], sys.argv[2])
    except Exception:
        print("Hermes provider reconciliation failed; check the private providers file and Hermes state.",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
