"""Exercise publishing, deletion, isolation, validation, and private diagnostics."""

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("reconcile-skills.py")
spec = importlib.util.spec_from_file_location("reconcile_skills", SCRIPT)
skills = importlib.util.module_from_spec(spec)
spec.loader.exec_module(skills)


class SkillsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.source = self.root / "secret.json"

    def publish(self, declarations):
        self.source.write_text(json.dumps(declarations), encoding="utf-8")
        skills.reconcile(self.source, self.home)

    def test_publish_update_remove_and_preserve_other_skills(self):
        unmanaged = self.home / "skills" / "interactive" / "SKILL.md"
        unmanaged.parent.mkdir(parents=True)
        unmanaged.write_text("Keep me")
        self.publish([{"name": "review", "category": "nixos", "files": {
            "SKILL.md": "Original", "scripts/run.sh": "#!/bin/sh\n"}}])
        target = self.home / "skills" / "nixos"
        original = target.resolve()
        self.assertEqual((target / "review" / "SKILL.md").read_text(), "Original")
        self.assertEqual((target / "review" / "SKILL.md").stat().st_mode & 0o777, 0o600)
        self.assertEqual((target / "review" / "scripts" / "run.sh").stat().st_mode & 0o777, 0o700)
        self.assertEqual(original.stat().st_mode & 0o777, 0o700)
        # Hermes's pinned index walker uses os.walk(..., followlinks=True).
        discovered = [Path(root) / "SKILL.md" for root, _, files in
                      os.walk(self.home / "skills", followlinks=True) if "SKILL.md" in files]
        self.assertIn(target / "review" / "SKILL.md", discovered)
        self.publish([{"name": "review", "category": "nixos", "files": {"SKILL.md": "Updated"}}])
        self.assertFalse(original.exists())
        self.assertEqual((target / "review" / "SKILL.md").read_text(), "Updated")
        self.assertFalse((target / "review" / "scripts").exists())
        self.publish([])
        self.assertFalse(target.exists())
        self.assertEqual(unmanaged.read_text(), "Keep me")

    def test_invalid_declarations_preserve_published_generation(self):
        self.publish([{"name": "review", "category": "nixos", "files": {"SKILL.md": "Keep me"}}])
        target = self.home / "skills" / "nixos"
        original = target.resolve()
        invalid = [
            {"review": {"SKILL.md": "x"}},
            [{"name": "../escape", "category": "nixos", "files": {"SKILL.md": "x"}}],
            [{"name": "review", "category": "nixos", "files": {}}],
            [{"name": "review", "category": "nixos", "files": {
                "SKILL.md": "x", "../escape": "x"}}],
            [{"name": "review", "category": "nixos", "files": {
                "SKILL.md": "x", "/absolute": "x"}}],
            [{"name": "review", "category": "nixos", "files": {
                "SKILL.md": "x", "a": "x", "a/b": "x"}}],
            [{"name": "review", "category": "nixos", "files": {
                "SKILL.md": "x", "a//b": "x"}}],
            [{"name": "review", "category": "nixos", "files": {
                "SKILL.md": "x", "a/SKILL.md": "x"}}],
            [{"name": "review", "category": "nixos", "files": {"SKILL.md": 42}}],
            [{"name": "review", "category": "nixos", "files": {"SKILL.md": "x"},
              "extra": True}],
            [{"name": "review", "category": "nixos", "files": {"SKILL.md": "x"}},
             {"name": "review", "category": "productivity", "files": {"SKILL.md": "x"}}],
        ]
        for declaration in invalid:
            with self.subTest(declaration=declaration), self.assertRaises(ValueError):
                self.publish(declaration)
            self.assertEqual(target.resolve(), original)
        self.assertEqual((target / "review" / "SKILL.md").read_text(), "Keep me")

    def test_adopt_existing_category_and_reject_unrelated_symlink(self):
        target = self.home / "skills" / "nixos"
        target.mkdir(parents=True)
        unmanaged = target / "interactive" / "SKILL.md"
        unmanaged.parent.mkdir()
        unmanaged.write_text("Keep me")
        self.publish([{"name": "review", "category": "nixos", "files": {
            "SKILL.md": "Managed"}}])
        self.assertTrue(target.is_symlink())
        self.assertEqual((target / "review" / "SKILL.md").read_text(), "Managed")
        self.assertEqual((target / "interactive" / "SKILL.md").read_text(), "Keep me")

        target.unlink()
        target.symlink_to(self.root)
        with self.assertRaises(ValueError):
            self.publish([])

    def test_duplicate_keys_and_private_errors(self):
        self.source.write_text('[{"name":"private-secret","category":"nixos","files":{},'
                               '"name":"private-secret"}]')
        result = subprocess.run([sys.executable, str(SCRIPT), str(self.source)],
                                env={**os.environ, "HERMES_HOME": str(self.home)},
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")
        self.assertNotIn("private-secret", result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        self.assertFalse(self.home.exists())

    def test_concurrent_service_startup(self):
        self.source.write_text(json.dumps([{"name": "review", "category": "nixos",
                                            "files": {"SKILL.md": "Shared"}}]))
        processes = [subprocess.Popen(
            [sys.executable, str(SCRIPT), str(self.source)],
            env={**os.environ, "HERMES_HOME": str(self.home)},
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            for _ in range(4)]
        for process in processes:
            output, error = process.communicate(timeout=10)
            self.assertEqual((process.returncode, output, error), (0, "", ""))
        self.assertEqual((self.home / "skills/nixos/review/SKILL.md").read_text(), "Shared")
        self.assertEqual(len(list((self.home / ".nixos-skills").glob("generation-*"))), 1)


if __name__ == "__main__":
    unittest.main()
