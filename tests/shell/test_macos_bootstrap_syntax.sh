#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

bash -n "$repo_root/macos/bootstrap.sh"
for module_file in "$repo_root"/macos/modules/*.sh; do
  bash -n "$module_file"
done

bootstrap_source="$(cat "$repo_root/macos/bootstrap.sh")"
if [[ "$bootstrap_source" != *"DEFAULT_MODULES=("*
  || "$bootstrap_source" != *"codex"* ]]; then
  echo "bootstrap.sh default module declaration is missing expected entries" >&2
  exit 1
fi

default_modules_block="$(sed -n '/DEFAULT_MODULES=(/,/)/p' "$repo_root/macos/bootstrap.sh")"
if [[ "$default_modules_block" == *"claude"* ]]; then
  echo "claude must remain an explicit opt-in macOS module" >&2
  exit 1
fi

if [[ ! -f "$repo_root/macos/modules/cleanup.sh" ]]; then
  echo "cleanup module is missing" >&2
  exit 1
fi

if [[ "$default_modules_block" == *"cleanup"* ]]; then
  echo "cleanup must remain an explicit opt-in macOS module" >&2
  exit 1
fi

if [[ "$bootstrap_source" != *'FORCE_NEOVIM_CLEANUP="${FORCE_NEOVIM_CLEANUP:-1}"'* ]]; then
  echo "macOS Neovim cleanup must be enabled by default" >&2
  exit 1
fi

codex_module_source="$(cat "$repo_root/macos/modules/codex.sh")"
if [[ "$codex_module_source" != *"upsert_codex_mcp_setting openaiDeveloperDocs startup_timeout_sec 30"* ]]; then
  echo "macOS Codex module must harden OpenAI Developer Docs MCP startup timeout" >&2
  exit 1
fi

if [[ "$codex_module_source" != *"upsert_codex_mcp_setting fetch default_tools_approval_mode"* ]]; then
  echo "macOS Codex module must require approval prompts for broad fetch MCP tools" >&2
  exit 1
fi

if ! grep -qF "ensure_codex_prefix_rule '[\"probe-rs\"]'" "$repo_root/macos/modules/codex.sh"; then
  echo "macOS Codex module must allow probe-rs hardware workflows" >&2
  exit 1
fi

if ! grep -qF "ensure_codex_prefix_rule '[\"stty\"]'" "$repo_root/macos/modules/codex.sh"; then
  echo "macOS Codex module must allow serial TTY configuration rule" >&2
  exit 1
fi

if [[ "$codex_module_source" != *'sandbox_mode = "workspace-write"'* ]]; then
  echo "macOS Codex module must create a sandbox permissions example" >&2
  exit 1
fi

echo "macos bootstrap syntax tests passed"
