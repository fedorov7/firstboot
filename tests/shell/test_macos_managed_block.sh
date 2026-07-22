#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$repo_root/macos/lib/managed_block.sh"

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

begin='<!-- BEGIN FIRSTBOOT CODEX AGENT TEAMWORK -->'
end='<!-- END FIRSTBOOT CODEX AGENT TEAMWORK -->'
input="$test_dir/input.md"
block="$test_dir/block.md"
output="$test_dir/output.md"

printf '%s\n' 'before' "$begin" 'old content' "$end" 'after' >"$input"
printf '%s\n' "$begin" 'new line one' 'new line two' "$end" >"$block"

replace_managed_block "$input" "$begin" "$end" "$block" >"$output"

printf '%s\n' 'before' "$begin" 'new line one' 'new line two' "$end" 'after' >"$test_dir/expected.md"
cmp "$test_dir/expected.md" "$output"

echo "macos managed block tests passed"
