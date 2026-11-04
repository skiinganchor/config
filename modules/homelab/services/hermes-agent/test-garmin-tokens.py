"""Test Garmin token reconciliation without real credentials."""

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("reconcile-garmin-tokens.py")


class GarminTokensTest(unittest.TestCase):
    def test_lifecycle(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            secret, directory = root / "secret", root / "tokens"
            token = directory / "garmin_tokens.json"
            secret.write_text("initial")

            def run():
                subprocess.run([sys.executable, SCRIPT, secret, directory], check=True)

            run()
            self.assertEqual(token.read_text(), "initial")
            self.assertEqual(token.stat().st_mode & 0o777, 0o600)
            token.write_text("refreshed")
            run()
            self.assertEqual(token.read_text(), "refreshed")
            secret.write_text("replacement")
            processes = [subprocess.Popen([sys.executable, SCRIPT, secret, directory]) for _ in range(2)]
            for process in processes:
                self.assertEqual(process.wait(), 0)
            self.assertEqual(token.read_text(), "replacement")
            token.unlink()
            run()
            self.assertEqual(token.read_text(), "replacement")

    def test_upgrade_preserves_existing_state(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            secret, directory = root / "secret", root / "tokens"
            secret.write_text("old snapshot")
            directory.mkdir()
            token = directory / "garmin_tokens.json"
            token.write_text("runtime session")
            subprocess.run([sys.executable, SCRIPT, secret, directory], check=True)
            self.assertEqual(token.read_text(), "runtime session")


if __name__ == "__main__":
    unittest.main()
