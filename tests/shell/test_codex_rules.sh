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
    (["fd", "--exec", "sh", "-c", "true"], "allow"),
    (["make", "test"], "allow"),
    (["cargo", "test"], "allow"),
    (["npm", "run", "test"], "allow"),
    (["git", "status", "--short"], "allow"),
    (["git", "branch", "--show-current"], "allow"),
    (["git", "-C", "/tmp/example", "push"], None),
    (["git", "push"], "prompt"),
    (["git", "reset", "--hard"], "prompt"),
    (["git", "branch", "-D", "example"], "prompt"),
    (["gh", "pr", "view", "1"], "allow"),
    (["gh", "pr", "merge", "1"], "prompt"),
    (["sudo", "true"], None),
    (["openocd", "-c", "shutdown"], "prompt"),
    (["west", "flash", "-d", "build"], "prompt"),
    (["ssh", "example.invalid", "true"], "allow"),
    (["git", "add", "README.md"], "allow"),
    (["git", "commit", "-m", "update"], "allow"),
    (["git", "commit", "--amend", "--no-edit"], "prompt"),
    (["git", "rebase", "main"], "prompt"),
    (["rm", "-rf", "/tmp/example"], "prompt"),
    (["scp", "example.invalid:/tmp/log", "/tmp/log"], "allow"),
    (["rsync", "-av", "example.invalid:/tmp/logs/", "/tmp/logs/"], "allow"),
    (["sshpass", "-e", "ssh", "example.invalid", "true"], "allow"),
    (["python3", "-m", "pytest", "tests"], "allow"),
    (["cmake", "--build", "build"], "allow"),
    (["west", "build", "-d", "build"], "allow"),
    # Document prefix limits: instruction-level checks cover these forms.
    (["git", "commit", "-m", "update", "--amend"], "allow"),
    (["ssh", "example.invalid", "rm -rf /tmp/example"], "allow"),

    (["gcc", "-o", "build/app", "main.c"], "allow"),
    (["cmake", "-S", ".", "-B", "build"], "allow"),
    (["cp", "new.c", "src/main.c"], "allow"),
    (["sed", "-i", "s/old/new/", "src/main.c"], "allow"),
    (["mkdir", "-p", "build"], "allow"),
    (["npm", "install", "--global", "typescript"], "allow"),
    (["cargo", "install", "ripgrep"], "allow"),
    (["python3", "-m", "pip", "install", "pytest"], "allow"),
    (["uv", "tool", "install", "ruff"], "allow"),
    (["sudo", "pacman", "-S", "ninja"], "allow"),
    (["sudo", "apt-get", "install", "ninja-build"], "allow"),
    (["sudo", "make", "install"], "allow"),
    (["sudo", "rm", "-rf", "/tmp/example"], "prompt"),
    (["sudo", "pacman", "-Rns", "ninja"], "prompt"),
    (["apt-get", "purge", "ninja-build"], "prompt"),

    (["gdb", "--batch", "-ex", "bt", "build/app"], "allow"),
    (["lldb", "build/app"], "allow"),
    (["strace", "-f", "build/app"], "allow"),
    (["valgrind", "build/app"], "allow"),
    (["perf", "record", "build/app"], "allow"),
    (["objdump", "-d", "build/app"], "allow"),
    (["uv", "run", "python", "tools/analyze.py"], "allow"),

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
