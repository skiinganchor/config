"""Run with the pinned Hermes package's hermesVenv/bin/python3."""

import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from dotenv import dotenv_values
import yaml


SCRIPT = Path(__file__).with_name("reconcile-providers.py")
DECLARATIONS = [
    {"provider": "openai-codex", "model": "gpt-6-luna",
     "id": "codex-primary",
     "tokens": {"access_token": "initial-access", "refresh_token": "initial-refresh"}},
    {"provider": "opencode-go", "model": "qwen3.7-plus", "id": "go-primary", "api_key": "go-secret"},
    {"provider": "zai", "model": "glm-5.2", "id": "zai-primary", "api_key": "zai-secret",
     "base_url": "https://api.z.ai/api/coding/paas/v4"},
]


class ProvidersTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.home = self.root / "hermes"
        self.home.mkdir(mode=0o700)
        self.secret = self.root / "providers.json"
        self.environment_file = self.root / "environment"
        self.environment_file.write_text("MATRIX_ACCESS_TOKEN='matrix-secret'\n")
        (self.home / "config.yaml").write_text(yaml.safe_dump({
            "model": {"provider": "custom", "default": "old", "api_key": "stale",
                      "base_url": "https://old.example", "key_env": "OLD_KEY", "api_mode": "responses",
                      "reasoning_effort": "low"},
            "mcp_servers": {"example": {"url": "https://example.org/mcp"}},
        }))
        (self.home / ".env").write_text("INTEGRATION_VALUE='preserved'\n")
        self.env = {**os.environ, "HERMES_HOME": str(self.home)}

    def run_python(self, code):
        result = subprocess.run([sys.executable, "-c", code], env=self.env,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def reconcile(self, declarations=None, success=True):
        self.secret.write_text(json.dumps(DECLARATIONS if declarations is None else declarations))
        result = subprocess.run([sys.executable, str(SCRIPT), str(self.secret), str(self.environment_file)],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0 if success else 1, result.stderr)
        return result

    def store(self):
        return json.loads((self.home / "auth.json").read_text())

    def test_installs_credentials_and_selects_model(self):
        self.reconcile()
        config = yaml.safe_load((self.home / "config.yaml").read_text())
        self.assertEqual(config["model"], {
            "provider": "openai-codex", "default": "gpt-6-luna", "reasoning_effort": "low"})
        self.assertIn("example", config["mcp_servers"])
        environment = dotenv_values(self.home / ".env")
        self.assertEqual(environment["MATRIX_ACCESS_TOKEN"], "matrix-secret")
        self.assertEqual(environment["INTEGRATION_VALUE"], "preserved")
        self.assertEqual(environment["OPENCODE_GO_API_KEY"], "go-secret")
        self.assertEqual(environment["GLM_API_KEY"], "zai-secret")
        self.assertEqual(environment["GLM_BASE_URL"], DECLARATIONS[2]["base_url"])
        codex = self.store()["credential_pool"]["openai-codex"][0]
        self.assertEqual({key: codex[key] for key in ("access_token", "refresh_token", "id")}, {
            "access_token": "initial-access", "refresh_token": "initial-refresh", "id": "codex-primary"})
        self.assertEqual(self.store()["providers"], {})
        for declaration in DECLARATIONS[1:]:
            row = self.store()["credential_pool"][declaration["provider"]][0]
            self.assertEqual(row["id"], declaration["id"])
            self.assertEqual(row["auth_type"], "api_key")
            self.assertTrue(row["source"].startswith("env:"))
            self.assertTrue(row["secret_fingerprint"].startswith("sha256:"))
            self.assertNotIn("access_token", row)
            self.assertNotIn(declaration["api_key"], json.dumps(self.store()))
        self.run_python("""
from agent.credential_pool import load_pool
from hermes_cli.auth import resolve_provider
from hermes_cli.auth_codex import resolve_codex_runtime_credentials
assert resolve_provider() == 'openai-codex'
assert resolve_codex_runtime_credentials(read_only=True)['api_key'] == 'initial-access'
for provider, credential_id, token in (
    ('openai-codex', 'codex-primary', 'initial-access'),
    ('opencode-go', 'go-primary', 'go-secret'),
    ('zai', 'zai-primary', 'zai-secret'),
):
    pool = load_pool(provider)
    assert len(pool.entries()) == 1
    entry = pool.select()
    assert entry.id == credential_id
    assert entry.runtime_api_key == token
""")
        for name in ("auth.json", ".env", "config.yaml"):
            self.assertEqual((self.home / name).stat().st_mode & 0o777, 0o600)

    def test_refresh_survives_restarts_and_model_changes(self):
        self.reconcile()
        self.run_python("""
from agent.credential_pool import load_pool
pool = load_pool('openai-codex')
pool._adopt(pool.entries()[0], access_token='rotated-access', refresh_token='rotated-refresh',
            last_refresh='2026-10-17T12:00:00Z', request_count=7, last_status='ok')
""")
        declarations = copy.deepcopy(DECLARATIONS)
        declarations[0]["model"] = "different-model"
        self.reconcile(declarations)
        self.assertEqual(self.store()["credential_pool"]["openai-codex"][0]["refresh_token"],
                         "rotated-refresh")
        self.assertEqual(self.store()["credential_pool"]["openai-codex"][0]["request_count"], 7)
        self.assertEqual(self.store()["providers"], {})
        declarations[0]["tokens"]["refresh_token"] = "replacement-session"
        self.reconcile(declarations)
        self.assertEqual(self.store()["credential_pool"]["openai-codex"][0]["refresh_token"],
                         "replacement-session")

    def test_zai_can_be_selected_as_default(self):
        self.reconcile([DECLARATIONS[2], DECLARATIONS[0], DECLARATIONS[1]])
        config = yaml.safe_load((self.home / "config.yaml").read_text())
        self.assertEqual(config["model"]["default"], "glm-5.2")
        self.run_python("""
from hermes_cli.auth import resolve_provider, get_api_key_provider_status
assert resolve_provider() == 'zai'
assert get_api_key_provider_status('zai')['logged_in']
""")

    def test_api_key_rotation_keeps_id_and_resets_status(self):
        self.reconcile()
        store = self.store()
        row = store["credential_pool"]["opencode-go"][0]
        row.update(request_count=12, last_status="exhausted", last_error_code=429)
        old_fingerprint = row["secret_fingerprint"]
        (self.home / "auth.json").write_text(json.dumps(store))
        self.reconcile()
        self.assertEqual(self.store()["credential_pool"]["opencode-go"][0]["request_count"], 12)
        declarations = copy.deepcopy(DECLARATIONS)
        declarations[1]["api_key"] = "rotated-go-secret"
        self.reconcile(declarations)
        row = self.store()["credential_pool"]["opencode-go"][0]
        self.assertEqual(row["id"], "go-primary")
        self.assertIsNone(row["last_status"])
        self.assertNotEqual(row["secret_fingerprint"], old_fingerprint)
        self.assertNotIn("access_token", row)

    def test_migrates_singleton_without_duplicating_or_replaying_grant(self):
        self.reconcile()
        store = self.store()
        row = store["credential_pool"]["openai-codex"][0]
        store["providers"]["openai-codex"] = {
            "tokens": {"access_token": "rotated-access", "refresh_token": "rotated-refresh"},
            "nixos_provider_seed_sha256": row["nixos_provider_seed_sha256"],
        }
        store["credential_pool"].pop("openai-codex")
        (self.home / "auth.json").write_text(json.dumps(store))
        self.reconcile()
        self.run_python("""
from agent.credential_pool import load_pool
pool = load_pool('openai-codex')
assert len(pool.entries()) == 1
assert pool.entries()[0].refresh_token == 'rotated-refresh'
assert pool.entries()[0].id == 'codex-primary'
""")
        self.assertEqual(self.store()["providers"], {})

    def test_adopts_existing_pool_id_and_retains_runtime_metadata(self):
        self.reconcile()
        store = self.store()
        row = store["credential_pool"]["openai-codex"][0]
        row.pop("nixos_provider_seed_sha256")
        row.update(source="device_code", access_token="live-access", refresh_token="live-refresh",
                   request_count=10, failure_reason="rate_limit")
        store["credential_pool"]["openai-codex"].append({
            **row, "id": "old-duplicate", "source": "manual:device_code"})
        (self.home / "auth.json").write_text(json.dumps(store))
        self.reconcile()
        self.run_python("""
from agent.credential_pool import load_pool
pool = load_pool('openai-codex')
assert len(pool.entries()) == 1
entry = pool.entries()[0]
assert entry.id == 'codex-primary'
assert entry.refresh_token == 'live-refresh'
assert entry.request_count == 10
assert entry.failure_reason == 'rate_limit'
""")

    def test_default_endpoints_do_not_probe_during_reconciliation(self):
        declarations = copy.deepcopy(DECLARATIONS)
        declarations[2].pop("base_url")
        self.secret.write_text(json.dumps(declarations))
        self.run_python(f"""
import runpy
from unittest.mock import patch
with patch('hermes_cli.auth.detect_zai_endpoint', side_effect=AssertionError('unexpected probe')):
    runpy.run_path({str(SCRIPT)!r})['reconcile']({str(self.secret)!r}, {str(self.environment_file)!r})
""")
        self.assertEqual(self.store()["credential_pool"]["zai"][0]["base_url"],
                         "https://api.z.ai/api/paas/v4")

    def test_rotation_switching_and_removal_clear_stale_credentials(self):
        self.reconcile()
        store = self.store()
        store["providers"]["unrelated"] = {"preserve": True}
        store["credential_pool"] = {"zai": [{"access_token": "stale"}],
                                    "unrelated": [{"preserve": True}]}
        store["suppressed_sources"] = {"opencode-go": ["env:OPENCODE_GO_API_KEY"]}
        (self.home / "auth.json").write_text(json.dumps(store))
        self.environment_file.write_text("MATRIX_ACCESS_TOKEN='rotated-matrix'\nZAI_API_KEY=legacy\n")
        declarations = [copy.deepcopy(DECLARATIONS[1])]
        declarations[0]["api_key"] = "new-'key\\with\nnewline"
        self.reconcile(declarations)
        environment = dotenv_values(self.home / ".env")
        self.assertEqual(environment["OPENCODE_GO_API_KEY"], declarations[0]["api_key"])
        self.assertEqual(environment["MATRIX_ACCESS_TOKEN"], "rotated-matrix")
        self.assertNotIn("ZAI_API_KEY", environment)
        self.assertNotIn("GLM_API_KEY", environment)
        self.assertNotIn("GLM_BASE_URL", environment)
        self.assertEqual(set(self.store()["providers"]), {"unrelated"})
        self.assertEqual(set(self.store()["credential_pool"]), {"unrelated", "opencode-go"})
        self.run_python("""
from hermes_cli.auth import resolve_provider, get_api_key_provider_status
assert resolve_provider() == 'opencode-go'
assert get_api_key_provider_status('opencode-go')['logged_in']
assert not get_api_key_provider_status('zai')['logged_in']
""")

    def test_invalid_declarations_change_no_runtime_files_and_hide_secrets(self):
        self.reconcile()
        before = {p.name: p.read_bytes() for p in self.home.iterdir() if p.is_file()}
        for declarations in (
            [], {}, [DECLARATIONS[0], DECLARATIONS[0]],
            [{"provider": "secret-unsupported", "model": "x", "api_key": "PRIVATE"}],
            [{"provider": "openai-codex", "model": "x", "id": "codex-primary", "tokens": {"access_token": "PRIVATE"}}],
            [{"provider": "zai", "model": "x", "id": "zai-primary", "api_key": ""}],
            [{"provider": "zai", "model": "x", "id": "zai-primary", "api_key": "PRIVATE", "unexpected": True}],
            [{"provider": "zai", "model": "x", "id": "zai-primary", "api_key": "PRIVATE", "base_url": "http://bad"}],
            [{"provider": "zai", "model": "zai/glm", "id": "zai-primary", "api_key": "PRIVATE"}],
            [{**DECLARATIONS[1], "id": ""}],
        ):
            with self.subTest(declarations=declarations):
                result = self.reconcile(declarations, success=False)
                self.assertNotIn("PRIVATE", result.stdout + result.stderr)
                self.assertNotIn("secret-unsupported", result.stdout + result.stderr)
                self.assertEqual(before, {p.name: p.read_bytes() for p in self.home.iterdir() if p.is_file()})


if __name__ == "__main__":
    unittest.main()
