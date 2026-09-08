# shellcheck shell=bash

# shellcheck source=/dev/null
source "$SCRIPT_ROOT/lib/codex_config.sh"
# shellcheck source=/dev/null
source "$SCRIPT_ROOT/lib/managed_block.sh"

write_step "Setting up Codex CLI..."

load_nvm
if command_exists nvm; then
  nvm use "$NODE_VERSION" >/dev/null 2>&1 || true
fi

if ! command_exists npm; then
  write_warn "npm not available. Run nodejs module first."
  return
fi

if ! npm ls -g @openai/codex >/dev/null 2>&1; then
  write_step "Installing Codex CLI..."
  npm install -g @openai/codex
  write_ok "Codex CLI installed"
elif [[ "$CODEX_UPDATE_ENABLED" == "1" || "$CODEX_UPDATE_ENABLED" == "true" ]]; then
  write_step "Updating Codex CLI..."
  npm install -g @openai/codex
  write_ok "Codex CLI updated"
else
  write_skip "Codex CLI already installed"
fi

if ! command_exists codex; then
  write_warn "codex not found in PATH after npm install. Restart shell and re-run this module."
  return
fi

codex_dir="$HOME/.codex"
config_toml="$codex_dir/config.toml"
mkdir -p "$codex_dir"
codex_rules_dir="$codex_dir/rules"
codex_default_rules="$codex_rules_dir/default.rules"
codex_permissions_example="$codex_dir/config.permissions.example.toml"
codex_agents_dir="$codex_dir/agents"
mkdir -p "$codex_rules_dir" "$codex_agents_dir"
touch "$config_toml"
chmod 700 "$codex_dir" "$codex_rules_dir" "$codex_agents_dir"
chmod 600 "$config_toml"

test_codex_mcp_configured() {
  local name="$1"
  [[ -f "$config_toml" ]] &&
    grep -Eq "^[[:space:]]*\[mcp_servers\.${name}\][[:space:]]*(#.*)?$" "$config_toml"
}

add_codex_mcp_if_missing() {
  local name="$1"
  shift
  if test_codex_mcp_configured "$name"; then
    write_skip "MCP $name already configured"
    return
  fi
  write_step "Adding MCP: $name..."
  "$@"
  write_ok "MCP $name added"
}

remove_codex_mcp_if_present() {
  local name="$1"
  if test_codex_mcp_configured "$name"; then
    codex mcp remove "$name"
    write_ok "Removed MCP: $name"
  fi
}

remove_codex_incompatible_fetch_mcp() {
  if ! test_codex_mcp_configured fetch; then
    return
  fi

  local fetch_block
  fetch_block="$(awk '
    /^[[:space:]]*\[mcp_servers\.fetch\][[:space:]]*(#.*)?$/ { in_section = 1; print; next }
    in_section && /^[[:space:]]*\[/ { exit }
    in_section { print }
  ' "$config_toml")"
  if [[ "$fetch_block" == *"mcp-server-fetch"* && "$fetch_block" != *"mcp<2"* ]]; then
    remove_codex_mcp_if_present fetch
    write_ok "Removed incompatible fetch MCP dependency resolution"
  fi
}

upsert_codex_mcp_setting() {
  local name="$1"
  local key="$2"
  local value="$3"
  if ! test_codex_mcp_configured "$name"; then
    return
  fi
  upsert_codex_table_setting "mcp_servers.${name}" "$key" "$value"
}

upsert_codex_table_setting() {
  local table="$1"
  local key="$2"
  local value="$3"
  local section="[$table]"
  touch "$config_toml"

  local temp_config
  temp_config="$(mktemp)"
  awk -v section="$section" -v key="$key" -v value="$value" '
    BEGIN { in_section = 0; section_seen = 0; setting_seen = 0 }
    $0 == section {
      in_section = 1
      section_seen = 1
      print
      next
    }
    in_section && /^\[/ {
      if (!setting_seen) {
        print key " = " value
        setting_seen = 1
      }
      in_section = 0
    }
    in_section && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      if (!setting_seen) {
        print key " = " value
        setting_seen = 1
      }
      next
    }
    { print }
    END {
      if (in_section && !setting_seen) {
        print key " = " value
        setting_seen = 1
      }
      if (!section_seen) {
        print ""
        print section
        print key " = " value
      }
    }
  ' "$config_toml" >"$temp_config"

  if cmp -s "$temp_config" "$config_toml"; then
    rm -f "$temp_config"
    write_skip "Codex $table.$key already set"
    return
  fi

  if ! codex_config_install_candidate "$temp_config" "$config_toml"; then
    rm -f "$temp_config"
    write_warn "Refusing invalid Codex config update for $table.$key"
    return 1
  fi
  rm -f "$temp_config"
  write_ok "Codex $table.$key = $value"
}

upsert_codex_top_level_setting() {
  local key="$1"
  local value="$2"
  touch "$config_toml"

  local temp_config
  temp_config="$(mktemp)"
  awk -v key="$key" -v value="$value" '
    BEGIN { top_level = 1; seen = 0 }
    top_level && /^\[/ {
      if (!seen) {
        print key " = " value
        seen = 1
      }
      top_level = 0
    }
    top_level && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      if (!seen) {
        print key " = " value
        seen = 1
      }
      next
    }
    { print }
    END {
      if (!seen) {
        print key " = " value
      }
    }
  ' "$config_toml" >"$temp_config"

  if cmp -s "$temp_config" "$config_toml"; then
    rm -f "$temp_config"
    write_skip "Codex $key already set"
    return
  fi

  if ! codex_config_install_candidate "$temp_config" "$config_toml"; then
    rm -f "$temp_config"
    write_warn "Refusing invalid Codex config update for $key"
    return 1
  fi
  rm -f "$temp_config"
  write_ok "Codex $key = $value"
}

initialize_codex_default_rules() {
  codex_rules_destination="$codex_default_rules"
  if [[ -f "$codex_rules_destination" ]]; then
    local backup_dir="$codex_rules_dir/backups"
    local backup
    mkdir -p "$backup_dir"
    chmod 700 "$backup_dir"
    backup="$(mktemp "$backup_dir/default.rules.XXXXXX")"
    cp "$codex_rules_destination" "$backup"
    chmod 600 "$backup"
    write_ok "Backed up Codex rules to $backup"
  fi
  codex_default_rules="$(mktemp "$codex_rules_dir/.default.rules.XXXXXX")"
  printf '# Managed by firstboot. Rebuilt from the current rules on every run.\n' >"$codex_default_rules"
}

complete_codex_default_rules() {
  if ! codex execpolicy check --rules "$codex_default_rules" -- git status >/dev/null; then
    rm -f "$codex_default_rules"
    codex_default_rules="$codex_rules_destination"
    write_warn "Generated Codex rules are invalid; original file preserved"
    return 1
  fi
  chmod 600 "$codex_default_rules"
  mv "$codex_default_rules" "$codex_rules_destination"
  codex_default_rules="$codex_rules_destination"
}

ensure_codex_prefix_rule() {
  local pattern="$1"
  local rule="$2"
  # This file is newly generated; there are no historical rules to migrate.
  if grep -qF "pattern = $pattern," "$codex_default_rules"; then
    return
  fi
  printf '\n%s\n' "$rule" >>"$codex_default_rules"
}

remove_codex_legacy_agents_table() {
  if [[ ! -f "$config_toml" ]]; then
    return
  fi

  local before
  before="$(cat "$config_toml")"
  perl -0pi -e 's/^\[agents\]\r?\n(?=(?:(?!^\[).*(?:\r?\n|$))*(?:max_threads|max_depth|job_max_runtime_seconds|interrupt_message)\s*=)(?:(?!^\[).*(?:\r?\n|$))*//mg' "$config_toml"
  if [[ "$(cat "$config_toml")" != "$before" ]]; then
    write_ok "Removed legacy Codex agents table"
  else
    write_skip "Legacy Codex agents table absent"
  fi
}

remove_codex_misplaced_top_level_settings() {
  if [[ ! -f "$config_toml" ]]; then
    return
  fi

  local temp_config
  temp_config="$(mktemp)"
  set +e
  awk '
    /^\[/ { section = $0 }
    section ~ /^\[(notice\.model_migrations|tui|tui\.model_availability_nux)\]$/ &&
    $0 ~ /^(model|model_reasoning_effort|service_tier|sandbox_mode|approval_policy|approvals_reviewer|check_for_update_on_startup|startup_timeout_sec)[[:space:]]*=/ {
      changed = 1
      next
    }
    { print }
    END {
      if (changed) {
        exit 2
      }
    }
  ' "$config_toml" >"$temp_config"
  local rc=$?
  set -e
  if [[ $rc -eq 2 ]]; then
    cp "$temp_config" "$config_toml"
    rm -f "$temp_config"
    write_ok "Removed misplaced Codex top-level settings"
    return
  fi

  rm -f "$temp_config"
  if [[ $rc -eq 0 ]]; then
    write_skip "Misplaced Codex top-level settings absent"
    return
  fi
  return "$rc"
}

ensure_codex_git_allow_rule() {
  local pattern="$1"
  local justification="$2"
  local example="$3"

  ensure_codex_prefix_rule "$pattern" "prefix_rule(
    pattern = $pattern,
    decision = \"allow\",
    justification = \"$justification\",
    match = [\"$example\"],
)"
}

ensure_codex_permissions_example() {
  local desired
desired="$(cat <<'EOF'
# Example only. Copy selected settings to ~/.codex/config.toml when needed.
model = "gpt-5.6-terra"
model_reasoning_effort = "medium"
model_verbosity = "low"
service_tier = "default"
sandbox_mode = "workspace-write"
approval_policy = "on-request"
approvals_reviewer = "user"
check_for_update_on_startup = true

[apps._default]
default_tools_approval_mode = "writes"
destructive_enabled = false
open_world_enabled = false
approvals_reviewer = "user"

[sandbox_workspace_write]
writable_roots = [
  "/home/alexander/example"
]
EOF
)"

  if [[ -f "$codex_permissions_example" ]] && [[ "$(cat "$codex_permissions_example")" == "$desired" ]]; then
    write_skip "Codex permissions example already current"
    return
  fi

  printf '%s\n' "$desired" >"$codex_permissions_example"
  write_ok "Codex permissions example updated"
}

write_codex_managed_file() {
  local path="$1"
  local content="$2"
  local description="$3"
  mkdir -p "$(dirname "$path")"
  if [[ -f "$path" ]] && [[ "$(cat "$path")" == "$content" ]]; then
    write_skip "$description already current"
    return
  fi
  local candidate
  candidate="$(mktemp)"
  printf '%s\n' "$content" >"$candidate"
  if ! codex_config_install_candidate "$candidate" "$path"; then
    rm -f "$candidate"
    write_warn "Refusing invalid $description"
    return 1
  fi
  rm -f "$candidate"
  write_ok "$description updated"
}

remove_codex_managed_file_if_present() {
  local path="$1"
  local description="$2"
  if [[ ! -f "$path" ]]; then
    write_skip "$description already absent"
    return
  fi
  rm -f "$path"
  write_ok "$description removed"
}

ensure_codex_profile_files() {
  if [[ "$CODEX_PROFILES_ENABLED" != "1" && "$CODEX_PROFILES_ENABLED" != "true" ]]; then
    remove_codex_managed_file_if_present "$codex_dir/lean.config.toml" "Codex lean profile"
    remove_codex_managed_file_if_present "$codex_dir/deep.config.toml" "Codex deep profile"
    return
  fi

  local lean_profile
  lean_profile="$(cat <<EOF
# Managed by firstboot. Use with: codex --profile lean
model = "$CODEX_LEAN_PROFILE_MODEL"
model_reasoning_effort = "$CODEX_LEAN_PROFILE_REASONING_EFFORT"
model_verbosity = "$CODEX_LEAN_PROFILE_VERBOSITY"
service_tier = "$CODEX_SERVICE_TIER"
sandbox_mode = "$CODEX_SANDBOX_MODE"
approval_policy = "$CODEX_APPROVAL_POLICY"
approvals_reviewer = "$CODEX_APPROVALS_REVIEWER"
web_search = "cached"
EOF
)"

  local deep_mcp_overrides=""
  local mcp_server
  local profile_mcp_servers=()
  while IFS= read -r mcp_server; do
    profile_mcp_servers+=("$mcp_server")
  done < <(split_csv "$CODEX_MCP_ALLOWLIST")
  while IFS= read -r mcp_server; do
    if ! array_contains "$mcp_server" "${profile_mcp_servers[@]}"; then
      continue
    fi
    if [[ "$mcp_server" == "fetch" ]] && ! command_exists uvx; then
      continue
    fi
    deep_mcp_overrides+=$'\n[mcp_servers.'"$mcp_server"$']\nenabled = true\n'
  done < <(split_csv "$CODEX_MCP_DEFAULT_DISABLED_SERVERS")

  local deep_profile
  deep_profile="$(cat <<EOF
# Managed by firstboot. Use with: codex --profile deep
model = "$CODEX_DEEP_PROFILE_MODEL"
model_reasoning_effort = "$CODEX_DEEP_PROFILE_REASONING_EFFORT"
model_verbosity = "$CODEX_DEEP_PROFILE_VERBOSITY"
service_tier = "$CODEX_SERVICE_TIER"
sandbox_mode = "$CODEX_SANDBOX_MODE"
approval_policy = "$CODEX_APPROVAL_POLICY"
approvals_reviewer = "$CODEX_APPROVALS_REVIEWER"

[apps._default]
default_tools_approval_mode = "$CODEX_APPS_DEFAULT_TOOLS_APPROVAL_MODE"
destructive_enabled = false
open_world_enabled = false
approvals_reviewer = "$CODEX_APPROVALS_REVIEWER"
$deep_mcp_overrides
EOF
)"

  write_codex_managed_file "$codex_dir/lean.config.toml" "$lean_profile" "Codex lean profile"
  write_codex_managed_file "$codex_dir/deep.config.toml" "$deep_profile" "Codex deep profile"
}

new_codex_custom_agent_content() {
  local name="$1"
  local description="$2"
  local model="$3"
  local reasoning_effort="$4"
  local sandbox_mode="$5"
  local nicknames="$6"
  local instructions="$7"
  cat <<EOF
# Managed by firstboot.
name = "$name"
description = "$description"
model = "$model"
model_reasoning_effort = "$reasoning_effort"
sandbox_mode = "$sandbox_mode"
nickname_candidates = [$nicknames]

developer_instructions = '''
$instructions
'''
EOF
}

ensure_codex_custom_agent_files() {
  local managed_agents=(explorer-terra reviewer-deep docs-researcher tester-terra architect-deep knowledge-curator improvement-researcher)
  local selected_agents=()
  local agent_name

  if [[ "$CODEX_CUSTOM_AGENTS_ENABLED" == "1" || "$CODEX_CUSTOM_AGENTS_ENABLED" == "true" ]]; then
    while IFS= read -r agent_name; do
      selected_agents+=("$agent_name")
    done < <(split_csv "$CODEX_CUSTOM_AGENTS")
  fi

  for agent_name in "${managed_agents[@]}"; do
    if ! array_contains "$agent_name" "${selected_agents[@]}"; then
      remove_codex_managed_file_if_present "$codex_agents_dir/$agent_name.toml" "Codex custom agent $agent_name"
    fi
  done

  if [[ "$CODEX_CUSTOM_AGENTS_ENABLED" != "1" && "$CODEX_CUSTOM_AGENTS_ENABLED" != "true" ]]; then
    return
  fi

  for agent_name in "${selected_agents[@]}"; do
    local content=""
    case "$agent_name" in
      explorer-terra)
        content="$(new_codex_custom_agent_content \
          "explorer-terra" \
          "Fast read-only repository exploration and large-file evidence gathering." \
          "$CODEX_LEAN_PROFILE_MODEL" \
          "$CODEX_LEAN_PROFILE_REASONING_EFFORT" \
          "read-only" \
          '"Scout", "Mapper", "Triage"' \
          "You are a read-only exploration agent. Inspect files, logs, docs, and command output. Do not edit files. Return only decision-relevant findings with file paths, commands used, and uncertainty where evidence is incomplete.")"
        ;;
      reviewer-deep)
        content="$(new_codex_custom_agent_content \
          "reviewer-deep" \
          "High-reasoning code review focused on bugs, regressions, security risks, and test gaps." \
          "$CODEX_DEEP_PROFILE_MODEL" \
          "$CODEX_DEEP_PROFILE_REASONING_EFFORT" \
          "read-only" \
          '"Reviewer", "Auditor", "Skeptic"' \
          "You are a read-only review agent. Prioritize concrete bugs, behavioral regressions, security risks, and missing tests. Cite exact files and lines when possible. Avoid style-only findings unless they block maintainability or correctness.")"
        ;;
      docs-researcher)
        content="$(new_codex_custom_agent_content \
          "docs-researcher" \
          "Targeted documentation research for current APIs, SDKs, frameworks, and platform behavior." \
          "$CODEX_LEAN_PROFILE_MODEL" \
          "$CODEX_LEAN_PROFILE_REASONING_EFFORT" \
          "read-only" \
          '"Researcher", "Librarian", "Verifier"' \
          "You are a documentation research agent. Prefer official docs and configured documentation MCP servers. Return concise guidance with source links, version assumptions, and any gaps that need verification before implementation.")"
        ;;
      tester-terra)
        content="$(new_codex_custom_agent_content \
          "tester-terra" \
          "Fast build, lint, typecheck, and test runner that reports focused failures without editing source." \
          "$CODEX_LEAN_PROFILE_MODEL" \
          "$CODEX_LEAN_PROFILE_REASONING_EFFORT" \
          "workspace-write" \
          '"Runner", "Verifier", "Harness"' \
          "You are a verification agent. Run focused build, lint, typecheck, and test commands requested by the parent thread. You may create normal build/test artifacts in the workspace, but do not edit source files. Return commands, exit codes, concise failure summaries, and likely next investigation targets.")"
        ;;
      architect-deep)
        content="$(new_codex_custom_agent_content \
          "architect-deep" \
          "High-reasoning architecture and migration analyst for ambiguous cross-module design decisions." \
          "$CODEX_DEEP_PROFILE_MODEL" \
          "$CODEX_DEEP_PROFILE_REASONING_EFFORT" \
          "read-only" \
          '"Architect", "Planner", "Strategist"' \
          "You are a read-only architecture agent. Analyze constraints, coupling, data flow, rollout risk, and tradeoffs. Do not edit files. Return a concise recommendation, alternatives rejected, and concrete files or interfaces that constrain the design.")"
        ;;
      knowledge-curator)
        content="$(new_codex_custom_agent_content \
          "knowledge-curator" \
          "Read-only project knowledge curator that proposes durable skills or documentation after non-trivial work." \
          "$CODEX_LEAN_PROFILE_MODEL" \
          "$CODEX_LEAN_PROFILE_REASONING_EFFORT" \
          "read-only" \
          '"Curator", "Archivist", "Analyst"' \
          "You are a read-only knowledge-curation agent. Inspect recent diffs, command results, failure modes, and successful fixes. Do not edit files or create skills. Return only reusable, evidence-backed knowledge-capture candidates using this format:
Candidate: short title
Evidence: files, commands, errors, or artifacts that prove this was useful
Reuse Trigger: when future Codex sessions should remember this
Recommended Target: skill, AGENTS.md, README, or no action
Draft Guidance: 3-6 lines of reusable instruction")"
        ;;
      improvement-researcher)
        content="$(new_codex_custom_agent_content \
          "improvement-researcher" \
          "Read-only external improvement researcher for tooling, process, skills, MCP, and agent workflow updates." \
          "$CODEX_LEAN_PROFILE_MODEL" \
          "$CODEX_LEAN_PROFILE_REASONING_EFFORT" \
          "read-only" \
          '"Researcher", "Scout", "Optimizer"' \
          "You are a read-only improvement research agent. Search current external information when requested: official docs, primary repositories, release notes, and credible technical posts when primary sources are insufficient. Do not edit files, install tools, change configuration, or create skills. Return ranked, evidence-backed improvement proposals using this format:
Finding: short title
Source: link or exact source name
Why It Matters: concrete benefit
Fit For This Repo: how it maps to current firstboot scripts, skills, agents, or docs
Risk Or Cost: security, maintenance, runtime, token, or compatibility concern
Suggested Next Step: adopt, test, document, defer, or reject")"
        ;;
      *)
        write_warn "Unknown Codex custom agent requested: $agent_name"
        ;;
    esac

    if [[ -n "$content" ]]; then
      write_codex_managed_file "$codex_agents_dir/$agent_name.toml" "$content" "Codex custom agent $agent_name"
    fi
  done
}

ensure_codex_agent_teamwork_skill() {
  local source_skill="$REPO_ROOT/codex/skills/codex-agent-teamwork"
  local target_skill="$codex_dir/skills/codex-agent-teamwork"

  if [[ "$CODEX_AGENT_TEAMWORK_SKILL_ENABLED" != "1" && "$CODEX_AGENT_TEAMWORK_SKILL_ENABLED" != "true" ]]; then
    if [[ -e "$target_skill" ]]; then
      rm -rf "$target_skill"
      write_ok "Codex agent teamwork skill removed"
    else
      write_skip "Codex agent teamwork skill already absent"
    fi
    return
  fi

  if [[ ! -f "$source_skill/SKILL.md" ]]; then
    write_warn "Codex agent teamwork skill source not found: $source_skill"
    return
  fi

  if [[ -d "$target_skill" ]] && diff -qr "$source_skill" "$target_skill" >/dev/null 2>&1; then
    write_skip "Codex agent teamwork skill already current"
    return
  fi

  rm -rf "$target_skill"
  mkdir -p "$codex_dir/skills"
  cp -R "$source_skill" "$target_skill"
  write_ok "Codex agent teamwork skill installed"
}

ensure_codex_global_agents_guidance() {
  local path="$codex_dir/AGENTS.md"
  local begin="<!-- BEGIN FIRSTBOOT CODEX AGENT TEAMWORK -->"
  local end="<!-- END FIRSTBOOT CODEX AGENT TEAMWORK -->"
  local block
  block="$(cat <<'EOF'
## Firstboot Agent Teamwork

Use $codex-agent-teamwork for non-trivial development, debugging, review, architecture, docs research, and multi-file changes.
Do not spawn subagents for simple one-file edits, direct questions, or mechanical fixes.
Prefer explorer-terra, docs-researcher, and tester-terra for read-heavy or verification work.
Use reviewer-deep and architect-deep only when high reasoning materially improves correctness.
Use knowledge-curator only near the end of non-trivial work when a reusable workflow, command, or debugging path may be worth saving.
Use improvement-researcher only when the task explicitly asks for external improvement research, tooling/process updates, useful skills, MCP servers, or agent workflow tuning.
Start with at most one subagent. Add a second only for independent verification or research, and a third only for high-risk work with a separate domain. Keep max_depth = 1 and wait for all subagents before integrating results.

## Scope and completion

Routine authorized development includes git add and ordinary commit, SSH diagnostics and file transfer, editing tracked files, compiling, installing utilities, and running debuggers/analysis tools. Use the configured allow rules without repeated confirmation; prefer workdir over git -C and direct tool commands over opaque shell wrappers.
Review the complete action before execution: deletion, rebase/reset/clean, commit --amend anywhere in the arguments, forced push, rsync --delete, remote destructive SSH commands, disk formatting, and removal of system services or features need explicit scope/authorization. Prefix rules cannot inspect remote shell strings, later flags, hooks, debugger commands, or build scripts; do not use those forms to bypass review. SSH/PowerShell tools are trusted execution paths, not guarantees that all their operations are safe. Keep credentials out of rules and command lines.

For answer, review, diagnose, or plan requests, inspect only the minimum relevant files, logs, and docs; report evidence and do not edit unless asked.
For change, build, or fix requests, make only the requested in-scope local change and run the smallest relevant non-destructive validation.
Do not add features, dependencies, refactors, configuration changes, documentation, or tests outside the acceptance criteria. Ask only when a concrete action exceeds the existing authorization, changes the target or side effects, is destructive outside the agreed scope, or incurs unapproved cost. Stop when the acceptance criteria and required validation pass.
EOF
)"

  mkdir -p "$codex_dir"
  touch "$path"

  if [[ "$CODEX_GLOBAL_AGENTS_GUIDANCE_ENABLED" != "1" && "$CODEX_GLOBAL_AGENTS_GUIDANCE_ENABLED" != "true" ]]; then
    if grep -qF "$begin" "$path"; then
      awk -v begin="$begin" -v end="$end" '
        $0 == begin { skip = 1; next }
        $0 == end { skip = 0; next }
        !skip { print }
      ' "$path" >"$path.tmp"
      mv "$path.tmp" "$path"
      write_ok "Codex global AGENTS.md teamwork guidance removed"
    else
      write_skip "Codex global AGENTS.md teamwork guidance already absent"
    fi
    return
  fi

  local desired
  desired="$(printf '%s\n%s\n%s\n' "$begin" "$block" "$end")"
  if grep -qF "$begin" "$path"; then
    local desired_path
    desired_path="$(mktemp)"
    printf '%s\n' "$desired" >"$desired_path"
    replace_managed_block "$path" "$begin" "$end" "$desired_path" >"$path.tmp"
    rm -f "$desired_path"
  elif [[ ! -s "$path" ]]; then
    printf '# Global Codex Guidance\n\n%s\n' "$desired" >"$path.tmp"
  else
    { sed '${/^$/d;}' "$path"; printf '\n\n%s\n' "$desired"; } >"$path.tmp"
  fi

  if cmp -s "$path.tmp" "$path"; then
    rm -f "$path.tmp"
    write_skip "Codex global AGENTS.md teamwork guidance already current"
    return
  fi
  mv "$path.tmp" "$path"
  write_ok "Codex global AGENTS.md teamwork guidance updated"
}

toml_bool() {
  local value
  value="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$value" in
    1 | true | yes | on) printf "true" ;;
    *) printf "false" ;;
  esac
}

upsert_codex_top_level_setting sandbox_mode "\"$CODEX_SANDBOX_MODE\""
upsert_codex_top_level_setting approval_policy "\"$CODEX_APPROVAL_POLICY\""
upsert_codex_top_level_setting model "\"$CODEX_MODEL\""
upsert_codex_top_level_setting model_reasoning_effort "\"$CODEX_MODEL_REASONING_EFFORT\""
upsert_codex_top_level_setting model_verbosity "\"$CODEX_MODEL_VERBOSITY\""
upsert_codex_top_level_setting service_tier "\"$CODEX_SERVICE_TIER\""
upsert_codex_top_level_setting approvals_reviewer "\"$CODEX_APPROVALS_REVIEWER\""
upsert_codex_top_level_setting check_for_update_on_startup "$(toml_bool "$CODEX_CHECK_FOR_UPDATE_ON_STARTUP")"
remove_codex_legacy_agents_table
remove_codex_misplaced_top_level_settings
upsert_codex_table_setting apps._default default_tools_approval_mode "\"$CODEX_APPS_DEFAULT_TOOLS_APPROVAL_MODE\""
upsert_codex_table_setting apps._default destructive_enabled "$(toml_bool "$CODEX_APPS_DESTRUCTIVE_ENABLED")"
upsert_codex_table_setting apps._default open_world_enabled "$(toml_bool "$CODEX_APPS_OPEN_WORLD_ENABLED")"
upsert_codex_table_setting apps._default approvals_reviewer "\"$CODEX_APPROVALS_REVIEWER\""

if ! codex_config_validate_runtime; then
  write_warn "Generated Codex config failed runtime validation; refusing to continue"
  return 1
fi

initialize_codex_default_rules

ensure_codex_git_allow_rule '["git", "status"]' \
  "Allow read-only Git status checks without repeated prompts" \
  "git status --short"
ensure_codex_git_allow_rule '["git", "ls-files"]' \
  "Allow read-only Git index listing without repeated prompts" \
  "git ls-files"
ensure_codex_git_allow_rule '["git", "ls-tree"]' \
  "Allow read-only Git tree inspection without repeated prompts" \
  "git ls-tree -r HEAD"
ensure_codex_git_allow_rule '["git", "rev-parse"]' \
  "Allow read-only Git revision parsing without repeated prompts" \
  "git rev-parse --show-toplevel"
ensure_codex_git_allow_rule '["git", "merge-base"]' \
  "Allow read-only Git merge-base calculations without repeated prompts" \
  "git merge-base HEAD main"
ensure_codex_git_allow_rule '["git", "remote", "get-url"]' \
  "Allow read-only Git remote URL lookup without repeated prompts" \
  "git remote get-url origin"
ensure_codex_git_allow_rule '["git", "branch", "--list"]' \
  "Allow read-only Git branch listing without repeated prompts" \
  "git branch --list"
ensure_codex_git_allow_rule '["git", "branch", "--show-current"]' \
  "Allow read-only current branch lookup without repeated prompts" \
  "git branch --show-current"
ensure_codex_git_allow_rule '["git", "tag", "--list"]' \
  "Allow read-only Git tag listing without repeated prompts" \
  "git tag --list"
ensure_codex_git_allow_rule '["git", "describe"]' \
  "Allow read-only Git describe lookups without repeated prompts" \
  "git describe --tags --always"
ensure_codex_git_allow_rule '["git", "add"]' \
  "Allow staging workspace changes without deleting files or rewriting history" \
  "git add README.md"
ensure_codex_prefix_rule '["rg"]' 'prefix_rule(
    pattern = ["rg"],
    decision = "allow",
    justification = "Allow ripgrep workspace searches without repeated prompts",
)'
ensure_codex_prefix_rule '["fd"]' 'prefix_rule(
    pattern = ["fd"],
    decision = "allow",
    justification = "Allow fd workspace file discovery without repeated prompts",
)'
ensure_codex_prefix_rule '["bat"]' 'prefix_rule(
    pattern = ["bat"],
    decision = "allow",
    justification = "Allow bat workspace file viewing without repeated prompts",
)'
ensure_codex_prefix_rule '["eza"]' 'prefix_rule(
    pattern = ["eza"],
    decision = "allow",
    justification = "Allow eza workspace directory listing without repeated prompts",
)'
ensure_codex_prefix_rule '["delta"]' 'prefix_rule(
    pattern = ["delta"],
    decision = "allow",
    justification = "Allow delta diff viewing without repeated prompts",
)'
ensure_codex_prefix_rule '["difft"]' 'prefix_rule(
    pattern = ["difft"],
    decision = "allow",
    justification = "Allow difftastic diff viewing without repeated prompts",
)'
ensure_codex_prefix_rule '["difftastic"]' 'prefix_rule(
    pattern = ["difftastic"],
    decision = "allow",
    justification = "Allow difftastic diff viewing without repeated prompts",
)'
ensure_codex_prefix_rule '["just"]' 'prefix_rule(
    pattern = ["just"],
    decision = "allow",
    justification = "Allow project Justfile workflows in trusted workspaces without repeated prompts",
)'
ensure_codex_prefix_rule '["make"]' 'prefix_rule(
    pattern = ["make"],
    decision = "allow",
    justification = "Allow Makefile workflows in trusted workspaces without repeated prompts",
    match = ["make test"],
)'
ensure_codex_prefix_rule '["uv", "run"]' 'prefix_rule(
    pattern = ["uv", "run"],
    decision = "allow",
    justification = "Allow uv run project commands in trusted workspaces without repeated prompts",
    match = ["uv run python -m pytest"],
    not_match = ["uvx ruff"],
)'
ensure_codex_prefix_rule '["cmake", "--build"]' 'prefix_rule(
    pattern = ["cmake", "--build"],
    decision = "allow",
    justification = "Allow trusted CMake workspace builds without repeated prompts",
    match = ["cmake --build --preset=dev-win64 --target format-check -j 4"],
)'
ensure_codex_prefix_rule '["ctest"]' 'prefix_rule(
    pattern = ["ctest"],
    decision = "allow",
    justification = "Allow trusted CTest workspace test runs without repeated prompts",
    match = ["ctest --preset=dev-win64 --output-on-failure"],
)'
ensure_codex_prefix_rule '["ninja"]' 'prefix_rule(
    pattern = ["ninja"],
    decision = "allow",
    justification = "Allow trusted Ninja workspace builds without repeated prompts",
    match = ["ninja -C build"],
)'
ensure_codex_prefix_rule '["meson", "compile"]' 'prefix_rule(
    pattern = ["meson", "compile"],
    decision = "allow",
    justification = "Allow trusted Meson workspace builds without repeated prompts",
    match = ["meson compile -C build"],
)'
ensure_codex_prefix_rule '["meson", "test"]' 'prefix_rule(
    pattern = ["meson", "test"],
    decision = "allow",
    justification = "Allow trusted Meson workspace test runs without repeated prompts",
    match = ["meson test -C build"],
)'
ensure_codex_prefix_rule '["cargo", "build"]' 'prefix_rule(
    pattern = ["cargo", "build"],
    decision = "allow",
    justification = "Allow trusted Cargo workspace builds without repeated prompts",
    match = ["cargo build --all-targets"],
)'
ensure_codex_prefix_rule '["cargo", "check"]' 'prefix_rule(
    pattern = ["cargo", "check"],
    decision = "allow",
    justification = "Allow trusted Cargo workspace checks without repeated prompts",
    match = ["cargo check --all-targets"],
)'
ensure_codex_prefix_rule '["cargo", "test"]' 'prefix_rule(
    pattern = ["cargo", "test"],
    decision = "allow",
    justification = "Allow trusted Cargo workspace tests without repeated prompts",
    match = ["cargo test"],
)'
ensure_codex_prefix_rule '["cargo", "clippy"]' 'prefix_rule(
    pattern = ["cargo", "clippy"],
    decision = "allow",
    justification = "Allow trusted Cargo clippy checks without repeated prompts",
    match = ["cargo clippy --all-targets --all-features -- -D warnings"],
)'
ensure_codex_prefix_rule '["cargo", "nextest"]' 'prefix_rule(
    pattern = ["cargo", "nextest"],
    decision = "allow",
    justification = "Allow trusted Cargo nextest runs without repeated prompts",
    match = ["cargo nextest run"],
)'
ensure_codex_prefix_rule '["python", "-m", "pytest"]' 'prefix_rule(
    pattern = ["python", "-m", "pytest"],
    decision = "allow",
    justification = "Allow trusted Python pytest runs without repeated prompts",
    match = ["python -m pytest"],
)'
ensure_codex_prefix_rule '["python3", "-m", "pytest"]' 'prefix_rule(
    pattern = ["python3", "-m", "pytest"],
    decision = "allow",
    justification = "Allow trusted Python 3 pytest runs without repeated prompts",
    match = ["python3 -m pytest"],
)'
ensure_codex_prefix_rule '["pytest"]' 'prefix_rule(
    pattern = ["pytest"],
    decision = "allow",
    justification = "Allow trusted pytest runs without repeated prompts",
    match = ["pytest tests"],
)'
ensure_codex_prefix_rule '["npm", "test"]' 'prefix_rule(
    pattern = ["npm", "test"],
    decision = "allow",
    justification = "Allow trusted npm test scripts without repeated prompts",
    match = ["npm test"],
)'
ensure_codex_prefix_rule '["npm", "run", "test"]' 'prefix_rule(
    pattern = ["npm", "run", "test"],
    decision = "allow",
    justification = "Allow trusted npm run test scripts without repeated prompts",
    match = ["npm run test"],
)'
ensure_codex_prefix_rule '["npm", "run", "build"]' 'prefix_rule(
    pattern = ["npm", "run", "build"],
    decision = "allow",
    justification = "Allow trusted npm run build scripts without repeated prompts",
    match = ["npm run build"],
)'
ensure_codex_prefix_rule '["npm", "run", "lint"]' 'prefix_rule(
    pattern = ["npm", "run", "lint"],
    decision = "allow",
    justification = "Allow trusted npm run lint scripts without repeated prompts",
    match = ["npm run lint"],
)'
ensure_codex_prefix_rule '["west", "build"]' 'prefix_rule(
    pattern = ["west", "build"],
    decision = "allow",
    justification = "Allow trusted Zephyr workspace builds without repeated prompts",
    match = ["west build -b mik32_evb"],
)'
ensure_codex_prefix_rule '["west", "flash"]' 'prefix_rule(
    pattern = ["west", "flash"],
    decision = "allow",
    justification = "Allow explicitly requested Zephyr hardware flashing without repeated prompts",
    match = ["west flash -d build"],
)'
ensure_codex_prefix_rule '[".venv/bin/west", "build"]' 'prefix_rule(
    pattern = [".venv/bin/west", "build"],
    decision = "allow",
    justification = "Allow virtualenv Zephyr workspace builds without repeated prompts",
    match = [".venv/bin/west build -b mik32_evb"],
)'
ensure_codex_prefix_rule '[".venv/bin/west", "flash"]' 'prefix_rule(
    pattern = [".venv/bin/west", "flash"],
    decision = "allow",
    justification = "Allow explicitly requested virtualenv Zephyr flashing without repeated prompts",
    match = [".venv/bin/west flash -d build"],
)'
ensure_codex_prefix_rule '["dmesg"]' 'prefix_rule(
    pattern = ["dmesg"],
    decision = "allow",
    justification = "Allow read-only kernel diagnostics outside sandbox",
    match = ["dmesg --level=err,warn"],
)'
ensure_codex_prefix_rule '["lsusb"]' 'prefix_rule(
    pattern = ["lsusb"],
    decision = "allow",
    justification = "Allow read-only USB device inspection outside sandbox",
    match = ["lsusb -t"],
)'
ensure_codex_prefix_rule '["usbreset"]' 'prefix_rule(
    pattern = ["usbreset"],
    decision = "allow",
    justification = "Allow explicitly requested USB device resets during hardware workflows",
    match = ["usbreset 1d50:6018"],
)'

ensure_codex_prefix_rule '["git", "push"]' 'prefix_rule(
    pattern = ["git", "push"],
    decision = "allow",
    justification = "Allow authorized development and utility installation without repeated prompts",
    match = ["git push"],
)'
ensure_codex_prefix_rule '["git", "reset", "--hard"]' 'prefix_rule(
    pattern = ["git", "reset", "--hard"],
    decision = "prompt",
    justification = "Prompt before discarding tracked workspace changes",
    match = ["git reset --hard HEAD"],
)'
ensure_codex_prefix_rule '["git", "reset"]' 'prefix_rule(
    pattern = ["git", "reset"],
    decision = "prompt",
    justification = "Prompt before moving HEAD or discarding tracked workspace changes",
    match = ["git reset --hard HEAD"],
)'
ensure_codex_prefix_rule '["git", "clean"]' 'prefix_rule(
    pattern = ["git", "clean"],
    decision = "prompt",
    justification = "Prompt before deleting untracked workspace files",
    match = ["git clean -fd"],
)'
ensure_codex_prefix_rule '["git", "restore"]' 'prefix_rule(
    pattern = ["git", "restore"],
    decision = "prompt",
    justification = "Prompt before restoring files and discarding local edits",
    match = ["git restore README.md"],
)'
ensure_codex_prefix_rule '["git", "checkout", "--"]' 'prefix_rule(
    pattern = ["git", "checkout", "--"],
    decision = "prompt",
    justification = "Prompt before checkout restores files and discards local edits",
    match = ["git checkout -- README.md"],
)'
ensure_codex_prefix_rule '["git", "rebase"]' 'prefix_rule(
    pattern = ["git", "rebase"],
    decision = "prompt",
    justification = "Prompt before rewriting local history",
    match = ["git rebase main"],
)'
ensure_codex_prefix_rule '["git", "commit", "--amend"]' 'prefix_rule(
    pattern = ["git", "commit", "--amend"],
    decision = "prompt",
    justification = "Prompt before amending commits and rewriting history",
    match = ["git commit --amend"],
)'
ensure_codex_prefix_rule '["git", "commit"]' 'prefix_rule(
    pattern = ["git", "commit"],
    decision = "allow",
    justification = "Allow authorized development and utility installation without repeated prompts",
    match = ["git commit -m update", "git commit --amend", "git commit -m update --amend"],
)'
ensure_codex_prefix_rule '["git", "branch", "-D"]' 'prefix_rule(
    pattern = ["git", "branch", "-D"],
    decision = "prompt",
    justification = "Prompt before deleting branch refs",
    match = ["git branch -D old-branch"],
)'
ensure_codex_prefix_rule '["git", "branch", "-d"]' 'prefix_rule(
    pattern = ["git", "branch", "-d"],
    decision = "prompt",
    justification = "Prompt before deleting branch refs",
    match = ["git branch -d old-branch"],
)'
ensure_codex_prefix_rule '["git", "tag", "-d"]' 'prefix_rule(
    pattern = ["git", "tag", "-d"],
    decision = "prompt",
    justification = "Prompt before deleting tag refs",
    match = ["git tag -d v1.0.0"],
)'
ensure_codex_prefix_rule '["git", "checkout", "-f"]' 'prefix_rule(
    pattern = ["git", "checkout", "-f"],
    decision = "prompt",
    justification = "Prompt before forced checkout discards local edits",
    match = ["git checkout -f main"],
)'
ensure_codex_prefix_rule '["git", "switch", "-C"]' 'prefix_rule(
    pattern = ["git", "switch", "-C"],
    decision = "prompt",
    justification = "Prompt before resetting an existing branch with switch -C",
    match = ["git switch -C topic HEAD~1"],
)'
ensure_codex_prefix_rule '["git", "switch", "--discard-changes"]' 'prefix_rule(
    pattern = ["git", "switch", "--discard-changes"],
    decision = "prompt",
    justification = "Prompt before switching branches and discarding local edits",
    match = ["git switch --discard-changes main"],
)'
ensure_codex_prefix_rule '["git", "rm"]' 'prefix_rule(
    pattern = ["git", "rm"],
    decision = "prompt",
    justification = "Prompt before removing tracked files",
    match = ["git rm old.txt"],
)'
ensure_codex_prefix_rule '["git", "stash", "drop"]' 'prefix_rule(
    pattern = ["git", "stash", "drop"],
    decision = "prompt",
    justification = "Prompt before deleting stashed changes",
    match = ["git stash drop stash@{0}"],
)'
ensure_codex_prefix_rule '["git", "stash", "clear"]' 'prefix_rule(
    pattern = ["git", "stash", "clear"],
    decision = "prompt",
    justification = "Prompt before deleting all stashed changes",
    match = ["git stash clear"],
)'
ensure_codex_prefix_rule '["git", "reflog", "expire"]' 'prefix_rule(
    pattern = ["git", "reflog", "expire"],
    decision = "prompt",
    justification = "Prompt before expiring reflog history",
    match = ["git reflog expire --expire=now --all"],
)'
ensure_codex_prefix_rule '["git", "gc", "--prune"]' 'prefix_rule(
    pattern = ["git", "gc", "--prune"],
    decision = "prompt",
    justification = "Prompt before pruning unreachable Git objects",
    match = ["git gc --prune"],
)'
ensure_codex_prefix_rule '["git", "gc", "--prune=now"]' 'prefix_rule(
    pattern = ["git", "gc", "--prune=now"],
    decision = "prompt",
    justification = "Prompt before pruning unreachable Git objects immediately",
    match = ["git gc --prune=now"],
)'
ensure_codex_prefix_rule '["doas"]' 'prefix_rule(
    pattern = ["doas"],
    decision = "prompt",
    justification = "Prompt before running commands with elevated privileges",
    match = ["doas pkg_add ripgrep"],
)'
ensure_codex_prefix_rule '["su"]' 'prefix_rule(
    pattern = ["su"],
    decision = "prompt",
    justification = "Prompt before switching users or running a root shell",
    match = ["su -"],
)'
ensure_codex_prefix_rule '["brew", "install"]' 'prefix_rule(
    pattern = ["brew", "install"],
    decision = "allow",
    justification = "Allow authorized development and utility installation without repeated prompts",
    match = ["brew install ripgrep"],
)'
ensure_codex_prefix_rule '["brew", "upgrade"]' 'prefix_rule(
    pattern = ["brew", "upgrade"],
    decision = "allow",
    justification = "Allow authorized development and utility installation without repeated prompts",
    match = ["brew upgrade"],
)'
ensure_codex_prefix_rule '["rustup"]' 'prefix_rule(
    pattern = ["rustup"],
    decision = "allow",
    justification = "Allow authorized development and utility installation without repeated prompts",
    match = ["rustup update stable"],
)'
ensure_codex_prefix_rule '["cargo", "install"]' 'prefix_rule(
    pattern = ["cargo", "install"],
    decision = "allow",
    justification = "Allow authorized development and utility installation without repeated prompts",
    match = ["cargo install cargo-nextest"],
)'
ensure_codex_prefix_rule '["uv", "tool", "install"]' 'prefix_rule(
    pattern = ["uv", "tool", "install"],
    decision = "allow",
    justification = "Allow authorized development and utility installation without repeated prompts",
    match = ["uv tool install ruff"],
)'
ensure_codex_prefix_rule '["uv", "tool", "upgrade"]' 'prefix_rule(
    pattern = ["uv", "tool", "upgrade"],
    decision = "allow",
    justification = "Allow authorized development and utility installation without repeated prompts",
    match = ["uv tool upgrade ruff"],
)'
ensure_codex_prefix_rule '["npm", "install", "-g"]' 'prefix_rule(
    pattern = ["npm", "install", "-g"],
    decision = "allow",
    justification = "Allow authorized development and utility installation without repeated prompts",
    match = ["npm install -g @openai/codex"],
)'
ensure_codex_prefix_rule '["npm", "install", "--global"]' 'prefix_rule(
    pattern = ["npm", "install", "--global"],
    decision = "allow",
    justification = "Allow authorized development and utility installation without repeated prompts",
    match = ["npm install --global @openai/codex"],
)'
ensure_codex_prefix_rule '["python", "-m", "pip", "install"]' 'prefix_rule(
    pattern = ["python", "-m", "pip", "install"],
    decision = "allow",
    justification = "Allow authorized development and utility installation without repeated prompts",
    match = ["python -m pip install pytest"],
)'
ensure_codex_prefix_rule '["python3", "-m", "pip", "install"]' 'prefix_rule(
    pattern = ["python3", "-m", "pip", "install"],
    decision = "allow",
    justification = "Allow authorized development and utility installation without repeated prompts",
    match = ["python3 -m pip install pytest"],
)'
ensure_codex_prefix_rule '["pipx", "install"]' 'prefix_rule(
    pattern = ["pipx", "install"],
    decision = "allow",
    justification = "Allow authorized development and utility installation without repeated prompts",
    match = ["pipx install poetry"],
)'
ensure_codex_prefix_rule '["launchctl"]' 'prefix_rule(
    pattern = ["launchctl"],
    decision = "prompt",
    justification = "Prompt before changing macOS launch services",
    match = ["launchctl list"],
)'
ensure_codex_prefix_rule '["mount"]' 'prefix_rule(
    pattern = ["mount"],
    decision = "prompt",
    justification = "Prompt before mounting filesystems",
    match = ["mount"],
)'
ensure_codex_prefix_rule '["umount"]' 'prefix_rule(
    pattern = ["umount"],
    decision = "prompt",
    justification = "Prompt before unmounting filesystems",
    match = ["umount /Volumes/example"],
)'

ensure_codex_prefix_rule '["probe-rs"]' 'prefix_rule(
    pattern = ["probe-rs"],
    decision = "allow",
    justification = "Allow probe-rs hardware workflows outside sandbox",
)'
ensure_codex_prefix_rule '["openocd"]' 'prefix_rule(
    pattern = ["openocd"],
    decision = "allow",
    justification = "Allow OpenOCD hardware workflows outside sandbox",
)'
ensure_codex_prefix_rule '["dfu-util"]' 'prefix_rule(
    pattern = ["dfu-util"],
    decision = "allow",
    justification = "Allow DFU hardware workflows outside sandbox",
)'
ensure_codex_prefix_rule '["picocom"]' 'prefix_rule(
    pattern = ["picocom"],
    decision = "allow",
    justification = "Allow serial console hardware workflows outside sandbox",
)'
ensure_codex_prefix_rule '["stty"]' 'prefix_rule(
    pattern = ["stty"],
    decision = "allow",
    justification = "Allow serial TTY configuration outside sandbox",
)'
ensure_codex_prefix_rule '["st-flash"]' 'prefix_rule(
    pattern = ["st-flash"],
    decision = "allow",
    justification = "Allow ST-Link flashing workflows outside sandbox",
)'
ensure_codex_prefix_rule '["st-info"]' 'prefix_rule(
    pattern = ["st-info"],
    decision = "allow",
    justification = "Allow ST-Link probe inspection outside sandbox",
)'
ensure_codex_prefix_rule '["st-util"]' 'prefix_rule(
    pattern = ["st-util"],
    decision = "allow",
    justification = "Allow ST-Link debug server workflows outside sandbox",
)'
ensure_codex_git_allow_rule '["git", "diff"]' \
  "Allow trusted Git inspection without repeated prompts" \
  "git diff"
ensure_codex_git_allow_rule '["git", "log"]' \
  "Allow trusted Git inspection without repeated prompts" \
  "git log"
ensure_codex_git_allow_rule '["git", "show"]' \
  "Allow trusted Git inspection without repeated prompts" \
  "git show"
ensure_codex_git_allow_rule '["git", "grep"]' \
  "Allow trusted Git inspection without repeated prompts" \
  "git grep"
ensure_codex_git_allow_rule '["git", "blame"]' \
  "Allow trusted Git inspection without repeated prompts" \
  "git blame"

# Trusted development, diagnostics, file editing, and installation.
ensure_codex_prefix_rule '["ssh"]' 'prefix_rule(
    pattern = ["ssh"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["sshpass"]' 'prefix_rule(
    pattern = ["sshpass"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["scp"]' 'prefix_rule(
    pattern = ["scp"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["sftp"]' 'prefix_rule(
    pattern = ["sftp"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["rsync"]' 'prefix_rule(
    pattern = ["rsync"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["gdb"]' 'prefix_rule(
    pattern = ["gdb"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["lldb"]' 'prefix_rule(
    pattern = ["lldb"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["valgrind"]' 'prefix_rule(
    pattern = ["valgrind"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["objdump"]' 'prefix_rule(
    pattern = ["objdump"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["llvm-objdump"]' 'prefix_rule(
    pattern = ["llvm-objdump"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["nm"]' 'prefix_rule(
    pattern = ["nm"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["file"]' 'prefix_rule(
    pattern = ["file"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["strings"]' 'prefix_rule(
    pattern = ["strings"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["xxd"]' 'prefix_rule(
    pattern = ["xxd"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["cmake"]' 'prefix_rule(
    pattern = ["cmake"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["uv", "sync"]' 'prefix_rule(
    pattern = ["uv", "sync"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["uv", "pip", "install"]' 'prefix_rule(
    pattern = ["uv", "pip", "install"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["uv", "tool", "run"]' 'prefix_rule(
    pattern = ["uv", "tool", "run"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["uvx"]' 'prefix_rule(
    pattern = ["uvx"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["npm", "install"]' 'prefix_rule(
    pattern = ["npm", "install"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["npm", "ci"]' 'prefix_rule(
    pattern = ["npm", "ci"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["pnpm", "install"]' 'prefix_rule(
    pattern = ["pnpm", "install"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["pnpm", "run"]' 'prefix_rule(
    pattern = ["pnpm", "run"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["yarn", "install"]' 'prefix_rule(
    pattern = ["yarn", "install"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["yarn", "run"]' 'prefix_rule(
    pattern = ["yarn", "run"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["cc"]' 'prefix_rule(
    pattern = ["cc"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["c++"]' 'prefix_rule(
    pattern = ["c++"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["gcc"]' 'prefix_rule(
    pattern = ["gcc"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["g++"]' 'prefix_rule(
    pattern = ["g++"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["clang"]' 'prefix_rule(
    pattern = ["clang"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["clang++"]' 'prefix_rule(
    pattern = ["clang++"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["ar"]' 'prefix_rule(
    pattern = ["ar"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["ld"]' 'prefix_rule(
    pattern = ["ld"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["swift"]' 'prefix_rule(
    pattern = ["swift"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["xcodebuild"]' 'prefix_rule(
    pattern = ["xcodebuild"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["otool"]' 'prefix_rule(
    pattern = ["otool"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["atos"]' 'prefix_rule(
    pattern = ["atos"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["sample"]' 'prefix_rule(
    pattern = ["sample"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["vmmap"]' 'prefix_rule(
    pattern = ["vmmap"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["leaks"]' 'prefix_rule(
    pattern = ["leaks"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["lsof"]' 'prefix_rule(
    pattern = ["lsof"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["ps"]' 'prefix_rule(
    pattern = ["ps"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["cp"]' 'prefix_rule(
    pattern = ["cp"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["mv"]' 'prefix_rule(
    pattern = ["mv"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["mkdir"]' 'prefix_rule(
    pattern = ["mkdir"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["touch"]' 'prefix_rule(
    pattern = ["touch"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["tee"]' 'prefix_rule(
    pattern = ["tee"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["sed"]' 'prefix_rule(
    pattern = ["sed"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["perl"]' 'prefix_rule(
    pattern = ["perl"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["install"]' 'prefix_rule(
    pattern = ["install"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["apply_patch"]' 'prefix_rule(
    pattern = ["apply_patch"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["chmod", "+x"]' 'prefix_rule(
    pattern = ["chmod", "+x"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["sudo", "make", "install"]' 'prefix_rule(
    pattern = ["sudo", "make", "install"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["sudo", "cmake", "--install"]' 'prefix_rule(
    pattern = ["sudo", "cmake", "--install"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["sudo", "installer", "-pkg"]' 'prefix_rule(
    pattern = ["sudo", "installer", "-pkg"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["git", "fetch"]' 'prefix_rule(
    pattern = ["git", "fetch"],
    decision = "allow",
)'
ensure_codex_prefix_rule '["git", "pull", "--ff-only"]' 'prefix_rule(
    pattern = ["git", "pull", "--ff-only"],
    decision = "allow",
)'

# Destructive operations retain review.
ensure_codex_prefix_rule '["rm"]' 'prefix_rule(
    pattern = ["rm"],
    decision = "prompt",
)'
ensure_codex_prefix_rule '["rmdir"]' 'prefix_rule(
    pattern = ["rmdir"],
    decision = "prompt",
)'
ensure_codex_prefix_rule '["shred"]' 'prefix_rule(
    pattern = ["shred"],
    decision = "prompt",
)'
ensure_codex_prefix_rule '["dd"]' 'prefix_rule(
    pattern = ["dd"],
    decision = "prompt",
)'
ensure_codex_prefix_rule '["newfs_apfs"]' 'prefix_rule(
    pattern = ["newfs_apfs"],
    decision = "prompt",
)'
ensure_codex_prefix_rule '["newfs_hfs"]' 'prefix_rule(
    pattern = ["newfs_hfs"],
    decision = "prompt",
)'
ensure_codex_prefix_rule '["reboot"]' 'prefix_rule(
    pattern = ["reboot"],
    decision = "prompt",
)'
ensure_codex_prefix_rule '["shutdown"]' 'prefix_rule(
    pattern = ["shutdown"],
    decision = "prompt",
)'
ensure_codex_prefix_rule '["sudo", ["rm", "rmdir", "dd", "diskutil", "newfs_apfs", "newfs_hfs", "reboot", "shutdown", "launchctl", "sh", "bash", "zsh"]]' 'prefix_rule(
    pattern = ["sudo", ["rm", "rmdir", "dd", "diskutil", "newfs_apfs", "newfs_hfs", "reboot", "shutdown", "launchctl", "sh", "bash", "zsh"]],
    decision = "prompt",
)'
ensure_codex_prefix_rule '["brew", "uninstall"]' 'prefix_rule(
    pattern = ["brew", "uninstall"],
    decision = "prompt",
)'
ensure_codex_prefix_rule '["rustup", "toolchain", "uninstall"]' 'prefix_rule(
    pattern = ["rustup", "toolchain", "uninstall"],
    decision = "prompt",
)'
ensure_codex_prefix_rule '["diskutil", ["list", "info", "activity"]]' 'prefix_rule(
    pattern = ["diskutil", ["list", "info", "activity"]],
    decision = "allow",
)'
ensure_codex_prefix_rule '["diskutil", ["eraseDisk", "eraseVolume", "partitionDisk", "zeroDisk", "secureErase"]]' 'prefix_rule(
    pattern = ["diskutil", ["eraseDisk", "eraseVolume", "partitionDisk", "zeroDisk", "secureErase"]],
    decision = "prompt",
)'
ensure_codex_prefix_rule '["diskutil", "apfs", ["deleteContainer", "deleteVolume"]]' 'prefix_rule(
    pattern = ["diskutil", "apfs", ["deleteContainer", "deleteVolume"]],
    decision = "prompt",
)'
ensure_codex_prefix_rule '["git", "push", ["--force", "-f", "--force-with-lease"]]' 'prefix_rule(
    pattern = ["git", "push", ["--force", "-f", "--force-with-lease"]],
    decision = "prompt",
)'
ensure_codex_git_allow_rule '["git", "config", "--get"]' \
  "Allow Git configuration inspection" \
  "git config --get user.name"
ensure_codex_git_allow_rule '["git", "config", "--global", "--get"]' \
  "Allow Git configuration inspection" \
  "git config --global --get user.name"
ensure_codex_git_allow_rule '["git", "config", "--list"]' \
  "Allow Git configuration inspection" \
  "git config --list"
ensure_codex_prefix_rule '["rsync", "--delete"]' 'prefix_rule(
    pattern = ["rsync", "--delete"],
    decision = "prompt",
)'
ensure_codex_prefix_rule '["sshpass", "-p"]' 'prefix_rule(
    pattern = ["sshpass", "-p"],
    decision = "prompt",
)'
complete_codex_default_rules
ensure_codex_permissions_example
ensure_codex_profile_files
ensure_codex_custom_agent_files
ensure_codex_agent_teamwork_skill
ensure_codex_global_agents_guidance

desired_mcp_servers=()
while IFS= read -r server_name; do
  if ! array_contains "$server_name" "${desired_mcp_servers[@]}"; then
    desired_mcp_servers+=("$server_name")
  fi
done < <(split_csv "$CODEX_MCP_ALLOWLIST")

if [[ "$CODEX_GITHUB_MCP_ENABLED" -eq 1 ]]; then
  if ! array_contains github "${desired_mcp_servers[@]}"; then
    desired_mcp_servers+=(github)
  fi
fi
if [[ "$CODEX_SERENA_ENABLED" -eq 1 ]]; then
  if ! array_contains serena "${desired_mcp_servers[@]}"; then
    desired_mcp_servers+=(serena)
  fi
fi
if [[ "$CODEX_PLAYWRIGHT_MCP_ENABLED" -eq 1 ]]; then
  if ! array_contains playwright "${desired_mcp_servers[@]}"; then
    desired_mcp_servers+=(playwright)
  fi
fi

if [[ -n "$GITHUB_TOKEN" ]]; then
  write_warn "GITHUB_TOKEN is not written to Codex MCP config. Export $CODEX_GITHUB_TOKEN_ENV_VAR before launching Codex."
fi

existing_mcp_servers=()
if [[ -f "$config_toml" ]]; then
  while IFS= read -r server_name; do
    if ! array_contains "$server_name" "${existing_mcp_servers[@]}"; then
      existing_mcp_servers+=("$server_name")
    fi
  done < <(sed -nE 's/^\[mcp_servers\.([^].]+)\]$/\1/p' "$config_toml")
fi

if [[ "$CODEX_PRUNE_DISABLED_OPTIONAL_MCP" -eq 1 && "$CODEX_MCP_PRUNE_UNMANAGED" -ne 1 ]]; then
  disabled_optional_mcp_servers=()
  if [[ "$CODEX_GITHUB_MCP_ENABLED" -ne 1 ]] && ! array_contains github "${desired_mcp_servers[@]}"; then
    disabled_optional_mcp_servers+=(github)
  fi
  if [[ "$CODEX_SERENA_ENABLED" -ne 1 ]] && ! array_contains serena "${desired_mcp_servers[@]}"; then
    disabled_optional_mcp_servers+=(serena)
  fi
  if [[ "$CODEX_PLAYWRIGHT_MCP_ENABLED" -ne 1 ]] && ! array_contains playwright "${desired_mcp_servers[@]}"; then
    disabled_optional_mcp_servers+=(playwright)
  fi

  for server_name in "${disabled_optional_mcp_servers[@]}"; do
    if array_contains "$server_name" "${existing_mcp_servers[@]}"; then
      codex mcp remove "$server_name"
      write_ok "Removed disabled optional MCP: $server_name"
    else
      write_skip "MCP $server_name already absent"
    fi
  done
fi

if [[ "$CODEX_MCP_PRUNE_UNMANAGED" -eq 1 ]]; then
  for server_name in "${existing_mcp_servers[@]}"; do
    if ! array_contains "$server_name" "${desired_mcp_servers[@]}"; then
      codex mcp remove "$server_name"
      write_ok "Removed unmanaged MCP: $server_name"
    fi
  done
fi

if array_contains github "${desired_mcp_servers[@]}" && [[ -f "$config_toml" ]] && grep -q '@modelcontextprotocol/server-github' "$config_toml"; then
  remove_codex_mcp_if_present github
  write_ok "Removed archived GitHub MCP entry"
fi

if array_contains context7 "${desired_mcp_servers[@]}" && [[ -f "$config_toml" ]] && grep -q '^\[mcp_servers.context7\]' "$config_toml" && grep -q '@upstash/context7-mcp' "$config_toml" && grep -q -- '--api-key' "$config_toml"; then
  remove_codex_mcp_if_present context7
  write_ok "Removed context7 MCP with inline API key"
fi

if array_contains context7 "${desired_mcp_servers[@]}"; then
  add_codex_mcp_if_missing context7 codex mcp add context7 -- npx -y @upstash/context7-mcp
fi
if array_contains openaiDeveloperDocs "${desired_mcp_servers[@]}"; then
  add_codex_mcp_if_missing openaiDeveloperDocs codex mcp add openaiDeveloperDocs --url https://developers.openai.com/mcp
fi
if array_contains microsoft-learn "${desired_mcp_servers[@]}"; then
  add_codex_mcp_if_missing microsoft-learn codex mcp add microsoft-learn --url https://learn.microsoft.com/api/mcp
fi
if array_contains memory "${desired_mcp_servers[@]}"; then
  memory_dir="$HOME/.local/share/codex"
  mkdir -p "$memory_dir"
  memory_file="$memory_dir/memory.jsonl"
  add_codex_mcp_if_missing memory codex mcp add memory --env "MEMORY_FILE_PATH=$memory_file" -- npx -y @modelcontextprotocol/server-memory
fi
if array_contains fetch "${desired_mcp_servers[@]}"; then
  if command_exists uvx; then
    remove_codex_incompatible_fetch_mcp
    add_codex_mcp_if_missing fetch codex mcp add fetch -- uvx --with 'mcp<2' mcp-server-fetch
  else
    write_warn "uvx not available. Run python module first to enable fetch MCP."
  fi
fi
if array_contains sequential-thinking "${desired_mcp_servers[@]}"; then
  add_codex_mcp_if_missing sequential-thinking codex mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
fi
if array_contains github "${desired_mcp_servers[@]}"; then
  add_codex_mcp_if_missing github codex mcp add github --url https://api.githubcopilot.com/mcp/ --bearer-token-env-var "$CODEX_GITHUB_TOKEN_ENV_VAR"
fi
if array_contains serena "${desired_mcp_servers[@]}"; then
  if command_exists uvx; then
    add_codex_mcp_if_missing serena codex mcp add serena -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server --project-from-cwd --context=codex
  else
    write_warn "uvx not available. Run python module first to enable Serena MCP."
  fi
fi
if array_contains playwright "${desired_mcp_servers[@]}"; then
  add_codex_mcp_if_missing playwright codex mcp add playwright -- npx -y @playwright/mcp@latest
fi

upsert_codex_mcp_setting context7 startup_timeout_sec 30
upsert_codex_mcp_setting openaiDeveloperDocs startup_timeout_sec 30
upsert_codex_mcp_setting microsoft-learn startup_timeout_sec 30
upsert_codex_mcp_setting fetch startup_timeout_sec 30
upsert_codex_mcp_setting fetch default_tools_approval_mode "\"$CODEX_FETCH_MCP_APPROVAL_MODE\""
while IFS= read -r server_name; do
  upsert_codex_mcp_setting "$server_name" enabled false
done < <(split_csv "$CODEX_MCP_DEFAULT_DISABLED_SERVERS")
upsert_codex_mcp_setting microsoft-learn default_tools_approval_mode "\"$CODEX_MICROSOFT_LEARN_MCP_APPROVAL_MODE\""
upsert_codex_mcp_setting github default_tools_approval_mode "\"$CODEX_GITHUB_MCP_APPROVAL_MODE\""
upsert_codex_mcp_setting serena default_tools_approval_mode "\"$CODEX_SERENA_MCP_APPROVAL_MODE\""
upsert_codex_mcp_setting playwright startup_timeout_sec 30
upsert_codex_mcp_setting playwright default_tools_approval_mode "\"$CODEX_PLAYWRIGHT_MCP_APPROVAL_MODE\""

skill_source_root="$HOME/.local/share/codex/skill-sources"
agents_skills_dir="$HOME/.agents/skills"
mkdir -p "$skill_source_root" "$agents_skills_dir"

sync_codex_skill_namespace() {
  local namespace="$1"
  local repo="$2"
  local source_dir_name="$3"
  local skills_csv="$4"
  local namespace_dir="$agents_skills_dir/$namespace"
  local source_dir="$skill_source_root/$source_dir_name"
  local selected_skills=()
  local skill_name

  mkdir -p "$namespace_dir"
  while IFS= read -r skill_name; do
    selected_skills+=("$skill_name")
  done < <(split_csv "$skills_csv")

  shopt -s nullglob
  for entry in "$namespace_dir"/*; do
    local entry_name
    entry_name="$(basename "$entry")"
    if ! array_contains "$entry_name" "${selected_skills[@]}"; then
      rm -rf "$entry"
      write_ok "Removed stale $namespace skill: $entry_name"
    fi
  done
  shopt -u nullglob

  if [[ ${#selected_skills[@]} -eq 0 ]]; then
    write_skip "$namespace skill allowlist is empty"
    return
  fi

  if [[ ! -d "$source_dir/.git" ]]; then
    write_step "Cloning $namespace skills..."
    git clone "$repo" "$source_dir"
    write_ok "$namespace skills cloned"
  else
    git -C "$source_dir" pull --ff-only >/dev/null
    write_skip "$namespace skills already cloned, updated"
  fi

  for skill_name in "${selected_skills[@]}"; do
    local source_skill="$source_dir/skills/$skill_name"
    local dest_skill="$namespace_dir/$skill_name"
    if [[ ! -d "$source_skill" ]]; then
      write_warn "Selected $namespace skill '$skill_name' was not found in $source_dir."
      continue
    fi
    if [[ -L "$dest_skill" ]] && [[ "$(readlink "$dest_skill")" == "$source_skill" ]]; then
      write_skip "$namespace skill already present: $skill_name"
      continue
    fi
    if [[ -e "$dest_skill" || -L "$dest_skill" ]]; then
      rm -rf "$dest_skill"
      write_ok "Removed stale $namespace skill entry: $skill_name"
    fi
    ln -s "$source_skill" "$dest_skill"
    write_ok "$namespace skill symlinked: $skill_name"
  done
}

sync_codex_repo_path_skill() {
  local namespace="$1"
  local repo="$2"
  local source_dir_name="$3"
  local skill_path="$4"
  local skill_name="$5"
  local source_dir="$skill_source_root/$source_dir_name"
  local source_skill
  local namespace_dir="$agents_skills_dir/$namespace"
  local dest_skill="$namespace_dir/$skill_name"

  if [[ ! -d "$source_dir/.git" ]]; then
    write_step "Cloning $namespace skill source..."
    git clone "$repo" "$source_dir"
    write_ok "$namespace skill source cloned"
  else
    git -C "$source_dir" pull --ff-only >/dev/null
    write_skip "$namespace skill source already cloned, updated"
  fi

  source_skill="$source_dir/$skill_path"
  if [[ ! -f "$source_skill/SKILL.md" ]]; then
    write_warn "Selected $namespace skill '$skill_name' was not found at $source_skill."
    return
  fi

  mkdir -p "$namespace_dir"
  shopt -s nullglob
  for entry in "$namespace_dir"/*; do
    local entry_name
    entry_name="$(basename "$entry")"
    if [[ "$entry_name" != "$skill_name" ]]; then
      rm -rf "$entry"
      write_ok "Removed stale $namespace skill: $entry_name"
    fi
  done
  shopt -u nullglob

  if [[ -L "$dest_skill" ]] && [[ "$(readlink "$dest_skill")" == "$source_skill" ]]; then
    write_skip "$namespace skill already present: $skill_name"
    return
  fi
  if [[ -e "$dest_skill" || -L "$dest_skill" ]]; then
    rm -rf "$dest_skill"
    write_ok "Removed stale $namespace skill entry: $skill_name"
  fi
  ln -s "$source_skill" "$dest_skill"
  write_ok "$namespace skill symlinked: $skill_name"
}

curated_skills=()
while IFS= read -r skill_name; do
  curated_skills+=("$skill_name")
done < <(split_csv "$CODEX_CURATED_SKILLS")

legacy_curated_skills=(
  api-designer architecture-designer cli-developer code-documenter
  code-reviewer cpp-pro debugging-wizard doc embedded-systems
  fullstack-guardian legacy-modernizer pandas-pro pdf python-pro
  rust-engineer secure-code-guardian security-reviewer spec-miner
  test-master the-fool
)

for skill_name in "${legacy_curated_skills[@]}"; do
  skill_dir="$codex_dir/skills/$skill_name"
  if ! array_contains "$skill_name" "${curated_skills[@]}" && [[ -d "$skill_dir" ]]; then
    rm -rf "$skill_dir"
    write_ok "Removed obsolete curated skill: $skill_name"
  fi
done

skill_installer="$codex_dir/skills/.system/skill-installer/scripts/install-skill-from-github.py"
if [[ -f "$skill_installer" ]]; then
  for skill_name in "${curated_skills[@]}"; do
    skill_dir="$codex_dir/skills/$skill_name"
    if [[ -d "$skill_dir" ]]; then
      write_skip "Curated skill already installed: $skill_name"
      continue
    fi
    write_step "Installing curated skill: $skill_name..."
    if python3 "$skill_installer" --repo openai/skills --path "skills/.curated/$skill_name"; then
      write_ok "Skill $skill_name installed"
    else
      write_warn "Curated skill not installed: $skill_name"
    fi
  done
else
  write_warn "Codex skill installer not found. Run 'codex' once to bootstrap, then re-run this module."
fi

if [[ "$CODEX_REMOVE_LEGACY_EXTERNAL_SKILL_SOURCES" -eq 1 ]]; then
  for legacy_dir in "$HOME/.codex/superpowers" "$HOME/.codex/claude-skills"; do
    if [[ -e "$legacy_dir" ]]; then
      rm -rf "$legacy_dir"
      write_ok "Removed legacy skill source directory: $legacy_dir"
    fi
  done
fi

sync_codex_skill_namespace superpowers https://github.com/obra/superpowers.git superpowers "$CODEX_SUPERPOWERS_SKILLS"
sync_codex_skill_namespace claude-skills https://github.com/Jeffallan/claude-skills.git claude-skills "$CODEX_CLAUDE_SKILLS"
sync_codex_skill_namespace karpathy-skills https://github.com/forrestchang/andrej-karpathy-skills.git karpathy-skills "$CODEX_KARPATHY_SKILLS"

if [[ "$CODEX_TIMESFM_SKILL_ENABLED" -eq 1 ]]; then
  sync_codex_repo_path_skill timesfm "$CODEX_TIMESFM_SKILL_REPO" timesfm "$CODEX_TIMESFM_SKILL_PATH" timesfm-forecasting
fi
