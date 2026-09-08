#!/usr/bin/env python3
"""Exercise macOS rule rebuilding and native execpolicy decisions for both platforms.

Windows rules are materialized from literal provisioning calls, without running
PowerShell or any of the commands under test. This is not a Windows sandbox test.
"""
import ast
import difflib
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def check(path, command, expected):
    result = subprocess.run(
        ["codex", "execpolicy", "check", "--rules", str(path), "--", *command],
        check=True, capture_output=True, text=True,
    )
    actual = json.loads(result.stdout).get("decision")
    assert actual == expected, (path.name, command, expected, actual)


def macos_rules(directory):
    source = (ROOT / "macos/modules/codex.sh").read_text()
    names = ["initialize_codex_default_rules", "complete_codex_default_rules",
             "ensure_codex_prefix_rule", "ensure_codex_git_allow_rule"]
    functions = []
    for name in names:
        functions.append(re.search(r"(?ms)^" + name + r"\(\) \{.*?^\}", source).group())
    start = source.index("\ninitialize_codex_default_rules\n")
    end = source.index("\nensure_codex_permissions_example\n", start)
    path = directory / "macos.rules"
    # Old prompts and unrelated allows must be backed up, not migrated.
    path.write_text('\n'.join([
        'prefix_rule(pattern = ["git", "commit"], decision = "prompt")',
        'prefix_rule(pattern = ["brew", "install"], decision = "prompt")',
        'prefix_rule(pattern = ["ssh"], decision = "prompt")',
        'prefix_rule(pattern = ["ssh"], decision = "allow")',
        'prefix_rule(pattern = ["sudo"], decision = "prompt")',
        'prefix_rule(pattern = ["custom-tool"], decision = "allow")',
    ]) + '\n')
    original = path.read_bytes()
    script = 'set -euo pipefail\nwrite_ok() { :; }\nwrite_skip() { :; }\nwrite_warn() { :; }\ncodex_default_rules="$1"\ncodex_rules_dir="${1%/*}"\n'
    script += '\n'.join(functions) + source[start:end]
    for iteration in range(2):
        subprocess.run(["bash", "-c", script, "rule-test", str(path)], check=True)
        current = path.read_bytes()
        if iteration:
            assert current == previous, "".join(difflib.unified_diff(previous.decode().splitlines(True), current.decode().splitlines(True)))
        previous = current
    backups = list((directory / "backups").iterdir())
    assert len(backups) == 2, "Every existing rules file must be backed up"
    assert original in [p.read_bytes() for p in backups]
    assert current in [p.read_bytes() for p in backups]
    assert all(p.suffix != ".rules" for p in backups)
    check(path, ["custom-tool"], None)
    # A validation failure must preserve the installed file.
    invalid = script[:script.index("\ninitialize_codex_default_rules\n")]
    invalid += '\ninitialize_codex_default_rules\nprintf "invalid_rule(\\n" >>"$codex_default_rules"\ncomplete_codex_default_rules\n'
    result = subprocess.run(["bash", "-c", invalid, "rule-test", str(path)], capture_output=True)
    assert result.returncode != 0
    assert path.read_bytes() == current, "Invalid candidate replaced the installed rules"
    return path


def windows_rules(directory):
    source = (ROOT / "windows/modules/codex.ps1").read_text()
    # Ignore helper definitions and consider only literal top-level rule calls.
    source = source[source.index("\nInitialize-CodexDefaultRules\n"):]
    events = []
    for match in re.finditer(r"(?ms)^(Add-CodexPrefixRuleIfMissing|Set-CodexPrefixRule) '([^']+)' @'\n(.*?)\n'@", source):
        events.append((match.start(), match[1], match[2], match[3]))
    for match in re.finditer(r"(?m)^(Add-CodexGitAllowRule|Set-CodexAllowRule) '([^']+)'", source):
        events.append((match.start(), match[1], match[2],
                       f'prefix_rule(pattern = {match[2]}, decision = "allow")'))
    rules = {}
    for _, method, pattern, rule in sorted(events):
        ast.literal_eval(pattern)  # Reject interpolation/nonliteral extraction.
        if method != "Add-CodexPrefixRuleIfMissing" or pattern not in rules:
            rules[pattern] = rule
    assert len(rules) > 100, "Windows rules extraction incomplete"
    path = directory / "windows.rules"
    path.write_text('\n\n'.join(rules.values()) + '\n')
    return path


COMMON = [
    (["git", "add", "README.md"], "allow"),
    (["git", "commit", "-m", "update"], "allow"),
    (["git", "diff"], "allow"),
    (["git", "rebase", "main"], "prompt"),
    (["git", "reset", "--hard", "HEAD"], "prompt"),
    (["git", "commit", "--amend"], "prompt"),
    (["rm", "-rf", "example"], "prompt"),
    (["ssh", "example.invalid", "true"], "allow"),
    (["sshpass", "-e", "ssh", "example.invalid", "true"], "allow"),
    (["scp", "example.invalid:log", "log"], "allow"),
    (["rsync", "-av", "src/", "example.invalid:dst/"], "allow"),
    (["gdb", "--batch", "build/app"], "allow"),
    (["lldb", "build/app"], "allow"),
    (["cmake", "-S", ".", "-B", "build"], "allow"),
    (["cargo", "install", "ripgrep"], "allow"),
    (["npm", "install", "--global", "typescript"], "allow"),
    (["uv", "tool", "install", "ruff"], "allow"),
    (["git", "-C", "example", "rebase", "main"], None),
    # Explicit trust boundaries: prefix rules cannot inspect nested code/flags.
    (["ssh", "example.invalid", "rm -rf example"], "allow"),
    (["git", "commit", "-m", "update", "--amend"], "allow"),
    (["git", "push", "--force"], "prompt"),
    (["rsync", "--delete", "src/", "dst/"], "prompt"),
    (["rsync", "-av", "--delete", "src/", "dst/"], "allow"),
    (["sshpass", "-p", "EXAMPLE_NOT_A_SECRET", "ssh", "example.invalid"], "prompt"),
]
MAC = [
    (["brew", "install", "ninja"], "allow"),
    (["brew", "upgrade", "ninja"], "allow"),
    (["brew", "uninstall", "ninja"], "prompt"),
    (["sudo", "make", "install"], "allow"),
    (["sudo", "rm", "-rf", "example"], "prompt"),
    (["cp", "a", "b"], "allow"),
    (["sed", "-i", "s/a/b/", "example"], "allow"),
    (["xcodebuild", "build"], "allow"),
    (["otool", "-L", "build/app"], "allow"),
    (["diskutil", "list"], "allow"),
    (["diskutil", "eraseDisk", "APFS", "Example", "disk9"], "prompt"),
    (["/usr/bin/zsh", "-lc", "true"], None),
]
WINDOWS = [
    (["winget", "install", "Microsoft.PowerShell"], "allow"),
    (["winget", "uninstall", "example"], "prompt"),
    (["Copy-Item", "a", "b"], "allow"),
    (["Set-Content", "example", "text"], "allow"),
    (["Remove-Item", "example", "-Recurse"], "prompt"),
    (["Remove-Service", "example"], "prompt"),
    (["reg", "delete", "HKCU\\Example"], "prompt"),
    (["Clear-Disk", "1"], "prompt"),
    (["bcdedit", "/enum"], "allow"),
    (["bcdedit", "/delete", "{example}"], "prompt"),
    (["dism", "/online", "/get-features"], "allow"),
    (["dism", "/Apply-Image", "/ImageFile:example.wim"], "prompt"),
    (["cl", "main.c"], "allow"),
    (["cdb", "app.exe"], "allow"),
    (["wsl", "-d", "Ubuntu", "--", "bash", "-lc", "make test"], "allow"),
    (["wsl.exe", "--exec", "gdb", "./app"], "allow"),
    (["ssh.exe", "example.invalid", "true"], "allow"),
    (["gdb.exe", "--batch", "app.exe"], "allow"),
    (["wsl", "--shutdown"], "allow"),
    (["wsl", "--install", "Ubuntu"], "prompt"),
    (["wsl", "--import", "Dev", "target", "image.tar"], "prompt"),
    (["wsl.exe", "--import-in-place", "Dev", "disk.vhdx"], "prompt"),
    (["wsl.exe", "--unregister", "Dev"], "prompt"),
    (["New-VM", "Dev"], "prompt"),
    (["Remove-VM", "Dev"], "prompt"),
    (["pwsh", "-Command", "Remove-Item example"], None),
]
with tempfile.TemporaryDirectory(prefix="codex-platform-rules-") as temporary:
    directory = Path(temporary)
    for path, cases in [(macos_rules(directory), COMMON + MAC),
                        (windows_rules(directory), COMMON + WINDOWS)]:
        for command, expected in cases:
            check(path, command, expected)
        print(f"{path.name}: {len(cases)} execpolicy checks passed")
print("macOS backup/rebuild/idempotency/failure-preservation passed; no commands under test executed")
