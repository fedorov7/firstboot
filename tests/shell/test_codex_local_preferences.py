#!/usr/bin/env python3
"""Apply the Linux config tasks in isolation; never provision the real workstation."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import tomllib

import yaml

ROOT = Path(__file__).resolve().parents[2]
TASKS = yaml.safe_load((ROOT / "roles/codex/tasks/main.yml").read_text())
DEFAULTS = yaml.safe_load((ROOT / "group_vars/all.yml").read_text())
NAMES = {
    "Ensure Codex config directory exists",
    "Check for existing Codex user configuration",
    "Select Codex configuration management mode",
    "Set Codex workspace access defaults and top-level options",
    "Set Codex runtime table defaults",
    "Remove misplaced Codex top-level settings from Codex-owned tables",
    "Validate Codex config TOML after managed cleanup",
    "Remove retired Codex steer feature flag",
    "Ensure Codex rules directory exists",
    "Install reviewed Codex rules baseline",
    "Configure Codex skill selection overrides",
    "Create Codex CLI profile files",
    "Harden Codex MCP server settings",
}


def run_linux(directory, existing):
    home = directory / ("existing" if existing else "fresh")
    config_dir = home / ".codex"
    config_dir.mkdir(parents=True)
    config = config_dir / "config.toml"
    original = '''model = "gpt-6-astra"
approval_policy = "on-request"
approvals_reviewer = "auto_review"
sandbox_mode = "workspace-write"
service_tier = "default"
web_search = "live"
[features]
steer = true
apps = false
[apps._default]
default_tools_approval_mode = "auto"
[mcp_servers.fetch]
command = "custom-fetch"
enabled = true
default_tools_approval_mode = "auto"
'''
    rules = config_dir / "rules/default.rules"
    if existing:
        config.write_text(original)
        rules.parent.mkdir()
        rules.write_text('prefix_rule(pattern = ["custom-tool"], decision = "allow")\n')
    selected = [dict(task) for task in TASKS if task["name"] in NAMES]
    assert len(selected) == len(NAMES)
    for task in selected:
        if task["name"] == "Install reviewed Codex rules baseline":
            task["copy"] = dict(task["copy"], src=str(ROOT / "roles/codex/files/default.rules"))
    play = [{"hosts": "localhost", "gather_facts": False,
             "vars": {**DEFAULTS, "user_home": str(home)}, "tasks": selected}]
    play_path = directory / "play.yml"
    play_path.write_text(yaml.safe_dump(play, sort_keys=False))

    def apply(extra=None):
        result = subprocess.run(
            ["ansible-playbook", "-i", "localhost,", "-c", "local", str(play_path),
             "-e", json.dumps(extra or {})], capture_output=True, text=True,
            env={**os.environ, "ANSIBLE_LOCAL_TEMP": str(directory / "ansible")},
        )
        assert result.returncode == 0, result.stdout + result.stderr
        return result.stdout

    apply()
    data = tomllib.loads(config.read_text())
    assert data["approvals_reviewer"] == "auto_review"
    if existing:
        assert config.read_text() == original.replace("steer = true\n", ""), "Existing preferences or omitted keys changed"
        assert "custom-tool" in rules.read_text(), "User rules were overwritten"
    else:
        assert data["model"] == "gpt-6.1-sol"
        assert data["sandbox_mode"] == "workspace-write"
        assert data["approval_policy"] == "on-request"
        assert data["apps"]["_default"]["approvals_reviewer"] == "auto_review"
    for name in ("lean", "deep", "astra"):
        profile = tomllib.loads((config_dir / f"{name}.config.toml").read_text())
        assert set(profile) == {"model", "model_reasoning_effort", "model_verbosity"}
    assert re.search(r"changed=0\s", apply()), "Repeat provisioning was not idempotent"
    if existing:
        apply({"codex_manage_existing_config": True, "codex_model": "gpt-6.1-sol"})
        assert tomllib.loads(config.read_text())["model"] == "gpt-6.1-sol"
        assert "custom-tool" in rules.read_text(), "Config opt-in must not reset rules"
    print(f"Linux {'existing' if existing else 'fresh'} config: PASS")


def run_macos(directory):
    source = (ROOT / "macos/modules/codex.sh").read_text()
    function = re.search(r"(?ms)^ensure_codex_profile_files\(\) \{.*?^\}", source).group()
    script = '''set -euo pipefail
codex_dir="$1"
CODEX_PROFILES_ENABLED=1
CODEX_LEAN_PROFILE_MODEL=gpt-5.6-terra
CODEX_LEAN_PROFILE_REASONING_EFFORT=medium
CODEX_LEAN_PROFILE_VERBOSITY=low
CODEX_DEEP_PROFILE_MODEL=gpt-6.1-sol
CODEX_DEEP_PROFILE_REASONING_EFFORT=high
CODEX_DEEP_PROFILE_VERBOSITY=medium
write_codex_managed_file() { printf '%s\n' "$2" > "$1"; }
'''+function+'\nensure_codex_profile_files\n'
    subprocess.run(["bash", "-c", script, "profile-test", str(directory)], check=True)
    for name in ("lean", "deep"):
        data = tomllib.loads((directory / f"{name}.config.toml").read_text())
        assert set(data) == {"model", "model_reasoning_effort", "model_verbosity"}
    # Existing configs must not reach setters, including MCP reconciliation.
    for end_marker in ("\nif ! codex_config_validate_runtime", "\nskill_source_root="):
        end = source.index(end_marker)
        start = source.rindex('\nif "$codex_configure_preferences"; then', 0, end)
        subprocess.run(["bash", "-euc", "codex_configure_preferences=false\n" + source[start:end]], check=True)
    print("macOS profile inheritance and existing config guards: PASS")


if __name__ == "__main__":
    with tempfile.TemporaryDirectory(prefix="firstboot-codex-preferences-") as temp:
        directory = Path(temp)
        run_linux(directory, False)
        run_linux(directory, True)
        run_macos(directory)
