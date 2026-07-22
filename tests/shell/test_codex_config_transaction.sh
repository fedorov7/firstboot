#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$repo_root/macos/lib/codex_config.sh"

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

target="$test_dir/config.toml"
valid_candidate="$test_dir/valid.toml"
invalid_candidate="$test_dir/invalid.toml"

printf '%s\n' 'model = "original"' >"$target"
printf '%s\n' 'model = "updated"' '[agents]' 'max_threads = 4' >"$valid_candidate"

codex_config_install_candidate "$valid_candidate" "$target"
grep -qF 'model = "updated"' "$target"

printf '%s\n' 'model = "broken' >"$invalid_candidate"
if codex_config_install_candidate "$invalid_candidate" "$target" 2>/dev/null; then
  echo "invalid TOML candidate must be rejected" >&2
  exit 1
fi

grep -qF 'model = "updated"' "$target"

linux_role="$repo_root/roles/codex/tasks/main.yml"
if ! grep -qF 'tomllib.loads' "$linux_role"; then
  echo "Linux Codex role must validate TOML candidates before installation" >&2
  exit 1
fi

echo "codex config transaction tests passed"
