#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

require_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"
  if ! grep -qF -- "$pattern" "$path"; then
    printf 'FAIL: %s\n' "$message" >&2
    exit 1
  fi
}

require_not_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"
  if grep -qF -- "$pattern" "$path"; then
    printf 'FAIL: %s\n' "$message" >&2
    exit 1
  fi
}

require_contains group_vars/all.yml 'codex_model: gpt-5.6-terra' \
  'Linux must use the balanced Terra model by default.'
require_contains group_vars/all.yml 'codex_model_reasoning_effort: medium' \
  'Linux must use medium reasoning by default.'
require_contains group_vars/all.yml 'codex_model_verbosity: low' \
  'Linux must keep routine responses concise.'
require_contains group_vars/all.yml 'codex_deep_profile_model: gpt-5.6-sol' \
  'Linux must preserve Sol for explicit deep work.'
require_contains group_vars/all.yml 'codex_deep_profile_reasoning_effort: high' \
  'Linux must preserve high reasoning for explicit deep work.'
require_contains roles/codex/tasks/main.yml 'model = "gpt-5.6-terra"' \
  'Linux permissions example must not restore the expensive default.'
require_contains macos/modules/codex.sh 'model = "gpt-5.6-terra"' \
  'macOS permissions example must not restore the expensive default.'
require_contains windows/modules/codex.ps1 'model = "gpt-5.6-terra"' \
  'Windows permissions example must not restore the expensive default.'
require_contains group_vars/all.yml 'codex_mcp_default_disabled_servers:' \
  'Linux must expose the default-disabled MCP allowlist.'

for server in memory fetch sequential-thinking; do
  require_contains roles/codex/tasks/main.yml "name: $server" \
    "Linux must manage the $server MCP state."
done
require_contains roles/codex/tasks/main.yml '[mcp_servers.{{ mcp_server }}]' \
  'Linux deep profile must enable optional MCP servers.'
require_contains roles/codex/tasks/main.yml 'intersect(codex_mcp_allowlist | default([]))' \
  'Linux deep profile must not create MCP tables outside the allowlist.'
require_contains roles/codex/tasks/main.yml "mcp_server != 'fetch' or uv_available.rc == 0" \
  'Linux deep profile must not enable fetch without uvx.'
require_contains roles/codex/tasks/main.yml 'key: enabled' \
  'Linux must write the base MCP enabled state.'
require_contains macos/modules/codex.sh 'upsert_codex_mcp_setting "$server_name" enabled false' \
  'macOS must disable optional MCP servers in the base config.'
require_contains macos/modules/codex.sh 'array_contains "$mcp_server" "${profile_mcp_servers[@]}"' \
  'macOS deep profile must not create MCP tables outside the allowlist.'
require_contains macos/modules/codex.sh 'command_exists uvx' \
  'macOS deep profile must not enable fetch without uvx.'
require_contains windows/modules/codex.ps1 "Set-CodexMcpSetting \$server 'enabled' 'false'" \
  'Windows must disable optional MCP servers in the base config.'
require_contains windows/modules/codex.ps1 '$_ -in $profileMcpServers' \
  'Windows deep profile must not create MCP tables outside the allowlist.'
require_contains windows/modules/codex.ps1 "\$_ -ne 'fetch' -or (Test-CommandExists uvx)" \
  'Windows deep profile must not enable fetch without uvx.'

require_contains macos/bootstrap.sh 'CODEX_MODEL="${CODEX_MODEL:-gpt-5.6-terra}"' \
  'macOS must use Terra by default.'
require_contains macos/bootstrap.sh 'CODEX_DEEP_PROFILE_MODEL="${CODEX_DEEP_PROFILE_MODEL:-gpt-5.6-sol}"' \
  'macOS must preserve Sol in the deep profile.'
require_contains windows/bootstrap.ps1 '[string]$CodexModel = "gpt-5.6-terra"' \
  'Windows must use Terra by default.'
require_contains windows/bootstrap.ps1 '[string]$CodexDeepProfileModel = "gpt-5.6-sol"' \
  'Windows must preserve Sol in the deep profile.'

require_contains codex/skills/codex-agent-teamwork/SKILL.md \
  'Start with at most one subagent.' \
  'Teamwork guidance must start with one subagent.'
require_not_contains codex/skills/codex-agent-teamwork/SKILL.md \
  'Use no more than three subagents by default.' \
  'Teamwork guidance must not default to three subagents.'

for removed_skill in using-superpowers brainstorming writing-plans executing-plans dispatching-parallel-agents; do
  require_not_contains group_vars/all.yml "  - $removed_skill" \
    "Broad workflow skill $removed_skill must not be enabled by default."
  require_not_contains macos/bootstrap.sh ",${removed_skill}," \
    "macOS must not enable broad workflow skill $removed_skill by default."
  require_not_contains windows/bootstrap.ps1 ",${removed_skill}," \
    "Windows must not enable broad workflow skill $removed_skill by default."
done

for removed_skill in code-reviewer debugging-wizard test-master architecture-designer cli-developer the-fool; do
  require_not_contains group_vars/all.yml "  - $removed_skill" \
    "Duplicated skill $removed_skill must not be enabled by default."
done

printf 'codex token budget defaults tests passed\n'
