"""
Tests for python.cli -- command-line interface.

Uses Click's CliRunner for isolated CLI testing without side effects.
These tests verify help output, argument parsing, and mock-backed command
invocation. The actual CLI commands are thin wrappers over bridge/settlement
modules tested elsewhere.
"""

import pytest
import subprocess
import sys


class TestCLIHelp:
    """Test help output via subprocess to avoid import-level hangs."""

    def _run_cli(self, *args):
        result = subprocess.run(
            [sys.executable, "-m", "python.cli"] + list(args),
            capture_output=True, text=True, timeout=10,
            cwd=str(__import__("pathlib").Path(__file__).resolve().parent.parent.parent),
        )
        return result

    def test_main_help(self):
        result = self._run_cli("--help")
        assert result.returncode == 0
        assert "Usage" in result.stdout

    def test_seed_all_help(self):
        result = self._run_cli("seed-all", "--help")
        assert result.returncode == 0
        assert "data-dir" in result.stdout

    def test_verify_help(self):
        result = self._run_cli("verify", "--help")
        assert result.returncode == 0

    def test_simulate_help(self):
        result = self._run_cli("simulate", "--help")
        assert result.returncode == 0

    def test_unknown_command(self):
        result = self._run_cli("nonexistent-command")
        assert result.returncode != 0

    def test_transact_missing_args(self):
        result = self._run_cli("transact")
        assert result.returncode != 0


class TestCLICommandsMocked:
    """Test CLI commands using Click's CliRunner with mocked dependencies."""

    def test_seed_all_calls_bridge(self):
        """Verify seed-all creates a COBOLBridge for each of 6 nodes."""
        import tempfile
        from unittest.mock import patch, MagicMock
        from click.testing import CliRunner
        from python.cli import cli

        runner = CliRunner()
        with patch("python.cli.COBOLBridge") as mock_bridge_cls:
            mock_bridge = MagicMock()
            mock_bridge.seed_demo_data.return_value = True
            mock_bridge_cls.return_value = mock_bridge
            with tempfile.TemporaryDirectory() as tmpdir:
                result = runner.invoke(cli, ["seed-all", "--data-dir", tmpdir])
                assert mock_bridge_cls.call_count == 6
