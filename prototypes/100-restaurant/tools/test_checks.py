"""Guard against false green checks and an incomplete suite after a failure."""
import subprocess
import tempfile
import unittest
import io
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

from run_checks import SUCCESS, load_suite, run_step, run_suite


class CheckRunnerTest(unittest.TestCase):
    def step(self, output, code=0):
        with tempfile.TemporaryDirectory() as folder, patch("run_checks.subprocess.run") as run, redirect_stdout(io.StringIO()):
            run.return_value = subprocess.CompletedProcess(["godot"], code, output)
            result = run_step("fixture", ["godot"], Path(folder), success=SUCCESS)
            self.assertTrue((Path(folder) / result["log"]).is_file())
            return result

    def test_real_completion_forms(self):
        for marker in ["PASS free pan 12 checks", "STORAGE_AND_POSTER_TESTS_PASSED",
                       "ADVANCED_COLLAGE_TESTS_PASSED checks=39", "PAPER_RECIPE_TESTS_PASSED checks=33",
                       "Asset alpha audit: 104 sprites, 0 errors"]:
            with self.subTest(marker=marker):
                self.assertTrue(self.step(marker)["passed"])

    def test_error_after_pass_cannot_be_green(self):
        for error in ["ERROR: stale layout", "SCRIPT ERROR: parse failed", "FAIL: layout"]:
            with self.subTest(error=error):
                self.assertFalse(self.step("PASS: something\n" + error)["passed"])

    def test_nonzero_exit_cannot_be_green(self):
        self.assertFalse(self.step("PASS: something", 1)["passed"])

    def test_early_quit_without_completion_cannot_be_green(self):
        self.assertFalse(self.step("Godot Engine v4.7.2")["passed"])

    def test_ansi_does_not_hide_failure(self):
        self.assertFalse(self.step("PASS: something\n\x1b[31mERROR: layout\x1b[0m")["passed"])

    def test_timeout_cannot_be_green(self):
        with tempfile.TemporaryDirectory() as folder, patch("run_checks.subprocess.run") as run, redirect_stdout(io.StringIO()):
            run.side_effect = subprocess.TimeoutExpired(["godot"], 120, output=b"PASS: early")
            self.assertFalse(run_step("fixture", ["godot"], Path(folder), success=SUCCESS)["passed"])

    def test_later_scripts_still_run_after_failure(self):
        with tempfile.TemporaryDirectory() as folder, patch("run_checks.subprocess.run") as run, redirect_stdout(io.StringIO()):
            run.side_effect = [subprocess.CompletedProcess([], 1, "ERROR: old expectation"),
                               subprocess.CompletedProcess([], 0, "PASS: later test")]
            results = run_suite("godot", ["first.gd", "second.gd"], Path(folder))
            self.assertEqual([r["passed"] for r in results], [False, True])
            self.assertEqual(run.call_count, 2)

    def test_manifest_has_existing_unique_scripts(self):
        suite = load_suite()
        self.assertIn("tests/test_reference_layout.gd", suite["scripts"])


if __name__ == "__main__":
    unittest.main()
