"""Run with the pinned Hermes hermesVenv's Python."""

import base64
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest


MODULE = Path(__file__).resolve().parent


class ProfilesTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.scripts = self.root / "scripts"
        self.scripts.mkdir()
        for source, name in (
            ("prepare-profile.py", "prepare.py"),
            ("reconcile-cron-jobs.py", "reconcile_cron.py"),
            ("reconcile-skills.py", "legacy_skills.py"),
        ):
            shutil.copyfile(MODULE / source, self.scripts / name)

    def profile(self, api_key="synthetic-key"):
        root = Path(tempfile.mkdtemp(prefix="fixture-", dir=self.root))
        (root / "config").write_text("model:\n  provider: opencode-go\n  default: test-model\n")
        (root / "env").write_text(f"OPENCODE_GO_API_KEY={api_key}\n")
        return root

    def command(self, root, *args):
        return [sys.executable, "-B", str(self.scripts / "prepare.py"),
                "--config", str(root / "config"), "--env", str(root / "env"), *map(str, args)]

    def environment(self, root):
        return {**os.environ, "HOME": str(root), "HERMES_HOME": str(root / ".hermes")}

    def run_profile(self, root, *args, ok=True):
        result = subprocess.run(self.command(root, *args), env=self.environment(root),
                                capture_output=True, text=True, timeout=30)
        if ok:
            self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "", ""))
        else:
            self.assertEqual(result.returncode, 1)
            self.assertNotIn("synthetic", result.stderr)
            self.assertNotIn("Traceback", result.stderr)

    def test_concurrent_profiles_and_secret_rotation(self):
        roots = [self.profile("synthetic-first"), self.profile("synthetic-second")]
        processes = [subprocess.Popen(self.command(root), env=self.environment(root),
                                      stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                     for root in [*roots, *roots]]
        for process in processes:
            output, error = process.communicate(timeout=30)
            self.assertEqual((process.returncode, output, error), (0, "", ""))
        one, two = [root / ".hermes/.env" for root in roots]
        self.assertIn("synthetic-first", one.read_text())
        self.assertIn("synthetic-second", two.read_text())
        self.assertEqual(one.stat().st_mode & 0o777, 0o600)
        self.assertEqual(one.parent.stat().st_mode & 0o777, 0o700)
        unchanged = two.stat().st_ino
        (roots[0] / "env").write_text("OPENCODE_GO_API_KEY='synthetic-rotated'\n")
        self.run_profile(roots[0])
        self.run_profile(roots[1])
        self.assertIn("synthetic-rotated", one.read_text())
        self.assertEqual(two.stat().st_ino, unchanged)
        (roots[0] / "env").write_text("OPENCODE_GO_API_KEY='synthetic-malformed\n")
        self.run_profile(roots[0], ok=False)
        self.assertIn("synthetic-rotated", one.read_text())

    def test_migrated_profile_is_discoverable_from_default(self):
        default = self.profile()
        named = self.profile()
        self.run_profile(default)
        self.run_profile(named)
        legacy_home = named / ".hermes"
        (legacy_home / "sessions" / "existing").write_text("preserved")
        profile_home = default / ".hermes" / "profiles" / "fixture"
        env = {**self.environment(named), "HERMES_HOME": str(profile_home)}
        for command in (
            [sys.executable, "-B", str(self.scripts / "prepare.py"),
             "--migrate-only", "--state-directory", str(named)],
            self.command(named, "--state-directory", named),
        ):
            result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=30)
            self.assertEqual((result.returncode, result.stderr), (0, ""))
        self.assertEqual(legacy_home.readlink(), profile_home)
        self.assertEqual((profile_home / "sessions" / "existing").read_text(), "preserved")
        result = subprocess.run(
            [sys.executable, "-B", "-c", "from hermes_cli.profiles import list_profile_names; "
             "assert list_profile_names() == ['default', 'fixture']"],
            env=self.environment(default), capture_output=True, text=True, timeout=30,
        )
        self.assertEqual((result.returncode, result.stderr), (0, ""))

    def test_managed_home_initialization(self):
        root = self.profile()
        self.run_profile(root)
        home = root / ".hermes"
        for name in ("cron", "sessions", "logs", "memories"):
            directory = home / name
            self.assertTrue(directory.is_dir())
            self.assertEqual(directory.stat().st_mode & 0o777, 0o700)
        result = subprocess.run(
            [sys.executable, "-B", "-c",
             "from hermes_cli.config_home import initialize_home; "
             "from pathlib import Path; import os; "
             "initialize_home(Path(os.environ['HERMES_HOME']), (), set())"],
            env={**self.environment(root), "HERMES_MANAGED": "NixOS"},
            capture_output=True, text=True, timeout=30,
        )
        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "", ""))
        marker = home / "sessions" / "existing"
        marker.write_text("preserved")
        self.run_profile(root)
        self.assertEqual(marker.read_text(), "preserved")

    def test_shared_model_and_profile_override(self):
        from hermes_yaml import safe_load

        root = self.profile()
        model = root / "model"
        model.write_text("provider: openrouter\ndefault: shared-model\n")
        rendered = root / ".hermes/config.yaml"
        self.run_profile(root, "--model", model)
        self.assertEqual(safe_load(rendered.read_text())["model"]["default"], "test-model")
        (root / "config").write_text("{}\n")
        self.run_profile(root, "--model", model)
        self.assertEqual(safe_load(rendered.read_text())["model"],
                         {"provider": "openrouter", "default": "shared-model"})
        model.write_text("provider: openrouter\ndefault: shared-model\napi_key: synthetic\n")
        self.run_profile(root, "--model", model, ok=False)

    def test_managed_skills_and_rotating_credentials(self):
        root = self.profile()
        archive = root / "skills.tar"
        payload = root / "skills"
        garmin = root / "garmin-seed"
        auth = root / "auth-seed"
        garmin.write_text('{"seed": 1}')
        auth.write_text('{"version": 1, "providers": {}}')

        def write_archive(name):
            with tarfile.open(archive, "w") as tar:
                data = b"---\nname: review\ndescription: A private skill\n---\n"
                info = tarfile.TarInfo(name)
                info.size = len(data)
                tar.addfile(info, io.BytesIO(data))
            payload.write_bytes(base64.b64encode(archive.read_bytes()))

        write_archive("review/SKILL.md")
        options = ("--auth", auth, "--garmin", garmin, "--skills-base64", payload)
        self.run_profile(root, *options)
        home = root / ".hermes"
        oauth = home / "auth.json"
        token = root / ".garminconnect/garmin_tokens.json"
        oauth.write_text('{"refreshed": 1}')
        token.write_text('{"refreshed": 2}')
        self.run_profile(root, *options)
        self.assertEqual(json.loads(oauth.read_text()), {"refreshed": 1})
        self.assertEqual(json.loads(token.read_text()), {"refreshed": 2})
        garmin.write_text('{"seed": 3}')
        self.run_profile(root, *options)
        self.assertEqual(json.loads(token.read_text()), {"seed": 3})
        write_archive("../synthetic-escape")
        self.run_profile(root, *options, ok=False)
        self.assertTrue((home / "managed-skills/review/SKILL.md").is_file())
        self.assertFalse((home / "synthetic-escape").exists())

    def test_cron_migrates_managed_ids_and_keeps_runtime_state(self):
        root = self.profile()
        self.run_profile(root)
        home = root / ".hermes"
        cron = home / "cron"
        cron.mkdir(exist_ok=True)
        store = cron / "jobs.json"
        next_run = "2025-04-25T10:00:00+00:00"
        active = {"id": "preserve-id", "nixos_managed_cron_id": "managed", "name": "previous",
                  "enabled": False, "state": "paused", "next_run_at": next_run,
                  "schedule": {"kind": "interval", "minutes": 120, "display": "every 120m"},
                  "repeat": {"times": None, "completed": 3}}
        unmanaged = {"id": "interactive", "name": "Keep me"}
        job = {"id": "managed", "name": "Updated", "schedule": "every 2h",
               "deliver": "matrix:!room:example.org", "prompt": "Run the synthetic fixture"}
        store.write_text(json.dumps({"jobs": [active, unmanaged]}))
        source = root / "cron-definitions"
        source.write_text(json.dumps([job]))
        self.run_profile(root, "--cron", source)
        managed, interactive = json.loads(store.read_text())["jobs"]
        self.assertEqual(managed["id"], "preserve-id")
        self.assertEqual(managed["repeat"]["completed"], 3)
        self.assertEqual(managed["next_run_at"], next_run)
        self.assertEqual(managed["state"], "paused")
        self.assertEqual(interactive, unmanaged)
        source.write_text(json.dumps({"jobs": [job, dict(job, id="second", deliver="local")]}))
        self.run_profile(root, "--cron", source)
        self.assertEqual([job["id"] for job in json.loads(store.read_text())["jobs"]],
                         ["preserve-id", "interactive", "second"])
        unchanged = store.stat().st_ino
        self.run_profile(root, "--cron", source)
        self.assertEqual(store.stat().st_ino, unchanged)
        source.write_text('{"jobs": []}')
        self.run_profile(root, "--cron", source)
        self.assertEqual(json.loads(store.read_text())["jobs"], [unmanaged])

    def test_legacy_inputs_and_skill_migration(self):
        from dotenv import dotenv_values
        from hermes_yaml import safe_load

        root = self.profile()
        config_file = root / "config"
        config_file.write_text(
            config_file.read_text() +
            "mcp_servers:\n"
            "  garmin:\n"
            "    command: garmin-mcp\n"
            "  nextcloud:\n"
            "    url: https://cloud.example.org/mcp\n"
            "    headers:\n"
            "      Authorization: 'Bearer ${NEXTCLOUD_APP_PASSWORD}'\n"
        )
        providers = root / "providers"
        providers.write_text(json.dumps([{
            "provider": "openai-codex",
            "model": "test-codex",
            "id": "codex-test",
            "tokens": {"access_token": "synthetic-access", "refresh_token": "synthetic-refresh"},
        }, {
            "provider": "opencode-go",
            "model": "test-go",
            "id": "go-test",
            "api_key": "synthetic-ra'\u005cw",
        }]))
        legacy_skills = root / "skills.json"
        legacy_skills.write_text(json.dumps([{"category": "notes", "name": "review",
                                            "files": {"SKILL.md": "Private review"}}]))
        self.run_profile(root, "--legacyProviders", providers, "--legacySkills", legacy_skills)
        home = root / ".hermes"
        config = safe_load((home / "config.yaml").read_bytes())
        self.assertEqual(config["model"], {"provider": "openai-codex", "default": "test-codex"})
        self.assertEqual(config["mcp_servers"]["garmin"]["command"], "garmin-mcp")
        self.assertEqual(config["mcp_servers"]["nextcloud"]["headers"]["Authorization"],
                         "Bearer ${NEXTCLOUD_APP_PASSWORD}")
        self.assertEqual(dotenv_values(home / ".env")["OPENCODE_GO_API_KEY"], "synthetic-ra'\u005cw")
        auth = json.loads((home / "auth.json").read_text())
        self.assertEqual(auth["credential_pool"]["openai-codex"][0]["refresh_token"], "synthetic-refresh")
        auth["credential_pool"]["openai-codex"][0]["refresh_token"] = "synthetic-rotated"
        (home / "auth.json").write_text(json.dumps(auth))
        self.run_profile(root, "--legacyProviders", providers, "--legacySkills", legacy_skills)
        self.assertEqual(json.loads((home / "auth.json").read_text()), auth)

        category = home / "skills/notes"
        (category / "interactive").mkdir()
        (category / "interactive/SKILL.md").write_text("Keep me")
        archive = root / "skills.tar"
        with tarfile.open(archive, "w"):
            pass
        payload = root / "skills"
        payload.write_bytes(base64.b64encode(archive.read_bytes()))
        self.run_profile(root, "--skills-base64", payload)
        self.assertFalse(category.is_symlink())
        self.assertFalse((category / "review").exists())
        self.assertEqual((category / "interactive/SKILL.md").read_text(), "Keep me")


if __name__ == "__main__":
    unittest.main()
