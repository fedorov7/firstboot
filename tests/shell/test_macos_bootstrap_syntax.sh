#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

bash -n "$repo_root/macos/bootstrap.sh"
for module_file in "$repo_root"/macos/modules/*.sh; do
  bash -n "$module_file"
done

bootstrap_source="$(cat "$repo_root/macos/bootstrap.sh")"
if [[ "$bootstrap_source" != *"DEFAULT_MODULES=("*
  || "$bootstrap_source" != *"codex"*
  || "$bootstrap_source" != *"claude"* ]]; then
  echo "bootstrap.sh default module declaration is missing expected entries" >&2
  exit 1
fi

echo "macos bootstrap syntax tests passed"
