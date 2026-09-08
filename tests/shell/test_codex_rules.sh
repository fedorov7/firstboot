#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
python3 - <<'PY'
import json
import subprocess

cases = [
    (["lsusb", "-t"], "allow"),
    (["python3", "-c", "print(1)"], None),
    (["/usr/bin/zsh", "-lc", "true"], None),
    (["env", "-u", "EXAMPLE", "sh", "-c", "true"], None),
    (["timeout", "1s", "sh", "-c", "true"], None),
    (["fd", "--exec", "sh", "-c", "true"], None),
    (["make", "test"], None),
    (["cargo", "test"], None),
    (["npm", "run", "test"], None),
    (["git", "status", "--short"], None),
    (["git", "branch", "--show-current"], None),
    (["git", "-C", "/tmp/example", "push"], None),
    (["git", "push"], "prompt"),
    (["git", "reset", "--hard"], "prompt"),
    (["git", "branch", "-D", "example"], "prompt"),
    (["gh", "pr", "view", "1"], None),
    (["gh", "pr", "merge", "1"], "prompt"),
    (["sudo", "true"], "prompt"),
    (["openocd", "-c", "shutdown"], "prompt"),
    (["west", "flash", "-d", "build"], "prompt"),
    (["ssh", "example.invalid", "true"], "prompt"),
]
for command, expected in cases:
    result = subprocess.run(
        ["codex", "execpolicy", "check", "--rules",
         "roles/codex/files/default.rules", "--", *command],
        check=True, capture_output=True, text=True,
    )
    actual = json.loads(result.stdout).get("decision")
    assert actual == expected, (command, expected, actual)
print(f"{len(cases)} rule decisions passed; no commands under test were executed")
PY
