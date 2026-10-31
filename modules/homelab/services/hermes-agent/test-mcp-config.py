"""Run with the pinned Hermes package's hermesVenv/bin/python3."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import yaml


SCRIPT = Path(__file__).with_name("merge-mcp-config.py")
SERVERS = {
    "nextcloud": {
        "url": "https://cloud.example.org/mcp/",
        "headers": {"Authorization": "Bearer ${NEXTCLOUD_APP_PASSWORD}"},
        "enabled": True,
    },
    "garmin": {
        "command": "/nix/store/test-uv/bin/uvx",
        "args": ["--python", "/nix/store/test-python/bin/python3", "garmin-mcp"],
        "connect_timeout": 180,
        "env": {"GARMINTOKENS": "/var/lib/hermes/.garminconnect"},
        "enabled": True,
    },
}


class McpConfigTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.config_path = self.root / "config.yaml"
        self.declarations = self.root / "mcp.json"
        self.private_config = {
            "dashboard": {"basic_auth": {"username": "test", "password": "PRIVATE"}},
            "model": {"provider": "openai-codex", "default": "test-model"},
        }
        self.config_path.write_text(yaml.safe_dump(self.private_config))
        (self.root / ".env").write_text("NEXTCLOUD_APP_PASSWORD=test-app-password\n")
        self.env = {**os.environ, "HERMES_HOME": str(self.root)}

    def merge(self, servers=None, success=True):
        self.declarations.write_text(json.dumps(SERVERS if servers is None else servers))
        result = subprocess.run([sys.executable, str(SCRIPT), str(self.declarations)],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0 if success else 1, result.stderr)
        return result

    def read_config(self):
        return yaml.safe_load(self.config_path.read_text())

    def test_private_config_and_nix_servers_reach_native_cli(self):
        self.merge()
        config = self.read_config()
        self.assertEqual(config, {**self.private_config, "mcp_servers": SERVERS})
        self.assertEqual(self.config_path.stat().st_mode & 0o777, 0o600)
        result = subprocess.run([sys.executable, "-c", """
from hermes_cli.env_loader import load_hermes_dotenv
load_hermes_dotenv()
from hermes_cli.mcp_config import cmd_mcp_list, _get_mcp_servers
servers = _get_mcp_servers()
assert servers['nextcloud']['headers']['Authorization'] == 'Bearer test-app-password'
cmd_mcp_list()
"""], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("nextcloud", result.stdout)
        self.assertIn("garmin", result.stdout)
        self.assertNotIn("No MCP servers configured", result.stdout)

    def test_nix_replaces_same_name_and_preserves_other_private_servers(self):
        custom = {"command": "private-command", "env": {"TOKEN": "PRIVATE"}}
        self.config_path.write_text(yaml.safe_dump({
            **self.private_config,
            "mcp_servers": {"custom": custom, "garmin": {"url": "https://stale.example.org"}},
        }))
        self.merge()
        config = self.read_config()
        self.assertEqual(config["mcp_servers"], {"custom": custom, **SERVERS})
        before = self.config_path.read_bytes()
        self.merge()
        self.assertEqual(self.config_path.read_bytes(), before)

    def test_reactivation_and_removal_do_not_restore_stale_nix_servers(self):
        self.merge()
        # Upstream re-installs the private config before the activation merge.
        self.config_path.write_text(yaml.safe_dump(self.private_config))
        updated = {"garmin": {**SERVERS["garmin"], "command": "/nix/store/new-uv/bin/uvx"}}
        self.merge(updated)
        self.assertEqual(self.read_config()["mcp_servers"], updated)

    def test_malformed_config_changes_nothing_and_hides_private_values(self):
        for content in ("dashboard: [PRIVATE", "- PRIVATE\n", "mcp_servers: PRIVATE\n"):
            with self.subTest(content=content):
                self.config_path.write_text(content)
                result = self.merge(success=False)
                self.assertEqual(self.config_path.read_text(), content)
                self.assertNotIn("PRIVATE", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
