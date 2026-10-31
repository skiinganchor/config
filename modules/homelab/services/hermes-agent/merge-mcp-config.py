"""Install Nix MCP definitions into a private Hermes runtime configuration."""

import contextlib
import io
import json
import logging
import os
import sys
import tempfile


def merge(path):
    import yaml
    from hermes_cli.auth import _auth_store_lock
    from hermes_constants import get_hermes_home

    with open(path, encoding="utf-8") as source:
        servers = json.load(source)
    if not isinstance(servers, dict) or any(not isinstance(row, dict) for row in servers.values()):
        raise ValueError("Expected MCP server mappings")

    config_path = get_hermes_home() / "config.yaml"
    # Share the providers reconciler's lock: activation and both services may
    # update the same config, and neither update may discard the other's work.
    with _auth_store_lock():
        with config_path.open(encoding="utf-8") as source:
            config = yaml.safe_load(source)
        if not isinstance(config, dict):
            raise ValueError("Expected a config mapping")
        existing = config.get("mcp_servers") or {}
        if not isinstance(existing, dict):
            raise ValueError("Expected an MCP server mapping")
        # A Nix definition owns the whole named entry, including its transport.
        # Preserve private servers with other names, and keep ${VAR} references
        # literal so Hermes resolves credentials from its runtime environment.
        config["mcp_servers"] = existing | servers
        fd, temporary = tempfile.mkstemp(prefix=".mcp-config.", dir=config_path.parent)
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as target:
                yaml.safe_dump(config, target, sort_keys=False)
                target.flush()
                os.fsync(target.fileno())
            os.replace(temporary, config_path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)


def main():
    os.umask(0o077)
    logging.disable(logging.CRITICAL)
    try:
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            merge(sys.argv[1])
    except Exception:
        print("Hermes MCP configuration merge failed; check the runtime config and Nix MCP definitions.",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
