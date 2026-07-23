#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

require_contains() {
  local file="$1"
  local needle="$2"
  local message="$3"

  if ! grep -Fq -- "$needle" "$repo_root/$file"; then
    printf 'FAIL: %s\nMissing in %s: %s\n' "$message" "$file" "$needle" >&2
    exit 1
  fi
}

require_not_contains() {
  local file="$1"
  local needle="$2"
  local message="$3"

  if grep -Fq -- "$needle" "$repo_root/$file"; then
    printf 'FAIL: %s\nUnexpected in %s: %s\n' "$message" "$file" "$needle" >&2
    exit 1
  fi
}

require_contains "group_vars/all.yml" "neovim_force_cleanup: false" \
  "Neovim cleanup must be opt-in by default."
require_contains "macos/bootstrap.sh" 'FORCE_NEOVIM_CLEANUP="${FORCE_NEOVIM_CLEANUP:-0}"' \
  "macOS Neovim cleanup must be opt-in by default."
require_contains "windows/bootstrap.ps1" '[bool]$ForceNeovimCleanup = $false' \
  "Windows Neovim cleanup must be opt-in by default."

require_not_contains "roles/claude/files/settings.json" '"Read(**)"' \
  "Claude must not globally bypass file-read prompts."
require_not_contains "roles/claude/files/settings.json" '"Bash(node:*)"' \
  "Claude must not auto-approve arbitrary Node execution."
require_not_contains "roles/claude/files/settings.json" '"Bash(npm:*)"' \
  "Claude must not auto-approve arbitrary npm execution."
require_contains "roles/claude/tasks/main.yml" "no_log: true" \
  "Claude GitHub token handling must be redacted from Ansible logs."
require_contains "roles/claude/tasks/main.yml" "Remove Claude MCP — github with inline token" \
  "Linux Claude recipe must remove legacy GitHub MCP entries with inline tokens."
require_contains "roles/claude/tasks/main.yml" '"GITHUB_PERSONAL_ACCESS_TOKEN":"${GITHUB_PERSONAL_ACCESS_TOKEN}"' \
  "Linux Claude recipe must use runtime GitHub token placeholder."
require_not_contains "roles/claude/tasks/main.yml" 'GITHUB_PERSONAL_ACCESS_TOKEN: "{{ github_token }}"' \
  "Linux Claude recipe must not pass PAT values into MCP config."
require_not_contains "roles/claude/tasks/main.yml" '"GITHUB_PERSONAL_ACCESS_TOKEN":"${GITHUB_PERSONAL_ACCESS_TOKEN:-}"' \
  "Linux Claude recipe must not configure an always-empty fallback token."
require_not_contains "macos/modules/claude.sh" 'GITHUB_PERSONAL_ACCESS_TOKEN=$GITHUB_TOKEN' \
  "macOS Claude recipe must not write PAT values into MCP config."
require_not_contains "windows/modules/claude.ps1" 'GITHUB_PERSONAL_ACCESS_TOKEN=$GithubToken' \
  "Windows Claude recipe must not write PAT values into MCP config."
require_not_contains "macos/modules/codex.sh" 'export "$CODEX_GITHUB_TOKEN_ENV_VAR=$GITHUB_TOKEN"' \
  "macOS Codex recipe must not export legacy GitHub token values into MCP setup."
require_not_contains "windows/modules/codex.ps1" '[System.Environment]::SetEnvironmentVariable($CodexGithubTokenEnvVar, $GithubToken' \
  "Windows Codex recipe must not persist legacy GitHub token values."
require_not_contains "windows/modules/codex.ps1" 'Set-Item -Path "Env:\$CodexGithubTokenEnvVar" -Value $GithubToken' \
  "Windows Codex recipe must not copy legacy GitHub token values into process env."

require_contains "roles/codex/tasks/main.yml" "Remove misplaced Codex top-level settings from Codex-owned tables" \
  "Linux Codex recipe must clean invalid top-level keys from Codex-owned tables."
require_contains "macos/modules/codex.sh" "remove_codex_misplaced_top_level_settings" \
  "macOS Codex recipe must clean invalid top-level keys from Codex-owned tables."
require_contains "windows/modules/codex.ps1" "Remove-CodexMisplacedTopLevelSettings" \
  "Windows Codex recipe must clean invalid top-level keys from Codex-owned tables."

require_not_contains "roles/codex/tasks/main.yml" 'pattern = ["git"],' \
  "Codex must not allow every git command outside the sandbox."
require_not_contains "macos/modules/codex.sh" "ensure_codex_prefix_rule '[\"git\"]'" \
  "macOS Codex must not allow every git command outside the sandbox."
require_not_contains "windows/modules/codex.ps1" "Add-CodexPrefixRuleIfMissing '[\"git\"]'" \
  "Windows Codex must not allow every git command outside the sandbox."
for pattern in \
  'pattern = ["git", "status"]' \
  'pattern = ["git", "ls-files"]' \
  'pattern = ["git", "ls-tree"]' \
  'pattern = ["git", "rev-parse"]' \
  'pattern = ["git", "merge-base"]' \
  'pattern = ["git", "remote", "get-url"]' \
  'pattern = ["git", "branch", "--list"]' \
  'pattern = ["git", "branch", "--show-current"]' \
  'pattern = ["git", "tag", "--list"]' \
  'pattern = ["git", "describe"]' \
  'pattern = ["git", "add"]'
do
  require_contains "roles/codex/tasks/main.yml" "$pattern" \
    "Codex git allowlist must keep safe daily git workflows convenient."
done
for pattern in \
  'pattern = ["git", "diff"]' \
  'pattern = ["git", "log"]' \
  'pattern = ["git", "show"]' \
  'pattern = ["git", "grep"]' \
  'pattern = ["git", "blame"]' \
  'pattern = ["git", "config", "--get"]' \
  'pattern = ["git", "config", "--global", "--get"]' \
  'pattern = ["git", "config", "--list"]' \
  'pattern = ["git", "commit"]' \
  'pattern = ["git", "fetch"]' \
  'pattern = ["git", "switch", "-c"]' \
  'pattern = ["git", "checkout", "-b"]'
do
  require_not_contains "roles/codex/tasks/main.yml" "$pattern" \
    "Codex must not broadly allow git mutations that prefix rules cannot constrain."
done

require_not_contains "macos/modules/codex.sh" \
  'upsert_codex_table_setting agents max_threads "$CODEX_AGENTS_MAX_THREADS"' \
  "macOS Codex recipe must not write legacy agents.max_threads."
require_not_contains "windows/modules/codex.ps1" \
  "Set-CodexTableSetting 'agents' 'max_threads' \$CodexAgentsMaxThreads" \
  "Windows Codex recipe must not write legacy agents.max_threads."
require_not_contains "README.md" "codex_agents_max_threads" \
  "Linux README must not document removed Codex agents setting."

require_not_contains "roles/codex/tasks/main.yml" '(?ms)^\[agents\]' \
  "Codex agents cleanup regex must not use dotall across TOML tables."
require_not_contains "macos/modules/codex.sh" '(?ms)^\[agents\]' \
  "macOS agents cleanup regex must not use dotall across TOML tables."
require_not_contains "windows/modules/codex.ps1" '(?ms)^\[agents\]' \
  "Windows agents cleanup regex must not use dotall across TOML tables."
for pattern in \
  "ensure_codex_git_allow_rule '[\"git\", \"diff\"]'" \
  "ensure_codex_git_allow_rule '[\"git\", \"log\"]'" \
  "ensure_codex_git_allow_rule '[\"git\", \"show\"]'" \
  "ensure_codex_git_allow_rule '[\"git\", \"grep\"]'" \
  "ensure_codex_git_allow_rule '[\"git\", \"blame\"]'" \
  "Add-CodexGitAllowRule '[\"git\", \"diff\"]'" \
  "Add-CodexGitAllowRule '[\"git\", \"log\"]'" \
  "Add-CodexGitAllowRule '[\"git\", \"show\"]'" \
  "Add-CodexGitAllowRule '[\"git\", \"grep\"]'" \
  "Add-CodexGitAllowRule '[\"git\", \"blame\"]'"
do
  case "$pattern" in
    ensure_*) require_not_contains "macos/modules/codex.sh" "$pattern" \
      "macOS Codex must not auto-allow output-capable git commands." ;;
    Add-*) require_not_contains "windows/modules/codex.ps1" "$pattern" \
      "Windows Codex must not auto-allow output-capable git commands." ;;
  esac
done

legacy_agents_sample="$(mktemp)"
legacy_agents_output="$(mktemp)"
misplaced_tui_sample="$(mktemp)"
misplaced_tui_output="$(mktemp)"
trap 'rm -f "$legacy_agents_sample" "$legacy_agents_output" "$misplaced_tui_sample" "$misplaced_tui_output"' EXIT
cat >"$legacy_agents_sample" <<'EOF'
model = "gpt-5.6-sol"

[agents]
max_threads = 4
max_depth = 1
job_max_runtime_seconds = 1800

[apps._default]
default_tools_approval_mode = "writes"
EOF

perl -0pe 's/^\[agents\]\r?\n(?=(?:(?!^\[).*(?:\r?\n|$))*(?:max_threads|max_depth|job_max_runtime_seconds|interrupt_message)\s*=)(?:(?!^\[).*(?:\r?\n|$))*//mg' \
  "$legacy_agents_sample" >"$legacy_agents_output"
if grep -Fq '[agents]' "$legacy_agents_output"; then
  printf 'FAIL: legacy [agents] table was not removed\n' >&2
  exit 1
fi
if ! grep -Fq '[apps._default]' "$legacy_agents_output"; then
  printf 'FAIL: legacy [agents] cleanup removed following TOML table\n' >&2
  exit 1
fi

cat >"$misplaced_tui_sample" <<'EOF'
[tui.model_availability_nux]
"gpt-5.5" = 4
"gpt-5.6-sol" = 3
startup_timeout_sec = 30
check_for_update_on_startup = true

[apps._default]
default_tools_approval_mode = "writes"
EOF

awk '
  /^\[/ { section = $0 }
  section ~ /^\[(notice\.model_migrations|tui|tui\.model_availability_nux)\]$/ &&
  $0 ~ /^(model|model_reasoning_effort|service_tier|sandbox_mode|approval_policy|approvals_reviewer|check_for_update_on_startup|startup_timeout_sec)[[:space:]]*=/ {
    next
  }
  { print }
' "$misplaced_tui_sample" >"$misplaced_tui_output"
if grep -Fq 'startup_timeout_sec = 30' "$misplaced_tui_output" ||
  grep -Fq 'check_for_update_on_startup = true' "$misplaced_tui_output"; then
  printf 'FAIL: misplaced TUI cleanup kept invalid top-level settings\n' >&2
  exit 1
fi
if ! grep -Fq '"gpt-5.6-sol" = 3' "$misplaced_tui_output" ||
  ! grep -Fq '[apps._default]' "$misplaced_tui_output"; then
  printf 'FAIL: misplaced TUI cleanup removed valid TUI data or following table\n' >&2
  exit 1
fi

printf 'policy hardening tests passed\n'
