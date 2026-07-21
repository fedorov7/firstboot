# shellcheck shell=bash

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
mkdir -p "$codex_rules_dir"

test_codex_mcp_configured() {
  local name="$1"
  [[ -f "$config_toml" ]] && grep -q "^\[mcp_servers\.${name}\]" "$config_toml"
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

  cp "$temp_config" "$config_toml"
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

  cp "$temp_config" "$config_toml"
  rm -f "$temp_config"
  write_ok "Codex $key = $value"
}

ensure_codex_prefix_rule() {
  local pattern="$1"
  local rule="$2"
  if [[ -f "$codex_default_rules" ]] && grep -qF "pattern = $pattern" "$codex_default_rules"; then
    write_skip "Codex rule already present: $pattern"
    return
  fi
  if [[ -s "$codex_default_rules" ]]; then
    printf '\n' >>"$codex_default_rules"
  fi
  printf '%s\n' "$rule" >>"$codex_default_rules"
  write_ok "Codex rule added: $pattern"
}

remove_codex_prefix_allow_rule() {
  local pattern="$1"
  local quiet="${2:-0}"
  if [[ ! -f "$codex_default_rules" ]]; then
    return
  fi

  local before
  before="$(cat "$codex_default_rules")"
  PATTERN="$pattern" perl -0pi -e '
    my $p = quotemeta($ENV{"PATTERN"});
    s/(?:^|\R)prefix_rule\((?:(?!^\s*prefix_rule\().)*?pattern\s*=\s*$p(?:(?!^\s*prefix_rule\().)*?decision\s*=\s*"allow"(?:(?!^\s*prefix_rule\().)*?\)\s*/\n/msg;
    s/\R{3,}/\n\n/g;
    s/\A\s+//;
    s/\s+\z/\n/;
  ' "$codex_default_rules"

  if [[ "$(cat "$codex_default_rules")" == "$before" ]]; then
    if [[ "$quiet" != "1" ]]; then
      write_skip "Unsafe Codex allow rule absent: $pattern"
    fi
  else
    write_ok "Removed unsafe Codex allow rule: $pattern"
  fi
}

remove_codex_unsafe_shell_wrapper_rules() {
  remove_codex_prefix_allow_rule '["pwsh"]'
  remove_codex_prefix_allow_rule '["wsl", "bash", "-lc"]'
  remove_codex_prefix_allow_rule '["wsl", "-e", "bash"]'
}

remove_codex_unsafe_system_mutator_rules() {
  local pattern
  for pattern in \
    '["sudo"]' \
    '["git", "push"]' \
    '["git", "reset", "--hard"]' \
    '["git", "clean"]' \
    '["git", "restore"]' \
    '["git", "checkout", "--"]' \
    '["git", "rebase"]' \
    '["doas"]' \
    '["su"]' \
    '["brew", "install"]' \
    '["brew", "upgrade"]' \
    '["rustup"]' \
    '["cargo", "install"]' \
    '["uv", "tool", "install"]' \
    '["uv", "tool", "upgrade"]' \
    '["npm", "install", "-g"]' \
    '["npm", "install", "--global"]' \
    '["python", "-m", "pip", "install"]' \
    '["python3", "-m", "pip", "install"]' \
    '["pipx", "install"]' \
    '["launchctl"]' \
    '["mount"]' \
    '["umount"]'
  do
    remove_codex_prefix_allow_rule "$pattern" 1
  done
}

ensure_codex_permissions_example() {
  local desired
desired="$(cat <<'EOF'
# Example only. Copy selected settings to ~/.codex/config.toml when needed.
model = "gpt-5.6-sol"
model_reasoning_effort = "high"
service_tier = "default"
sandbox_mode = "workspace-write"
approval_policy = "on-request"
approvals_reviewer = "user"
check_for_update_on_startup = true

[agents]
max_threads = 4
max_depth = 1
job_max_runtime_seconds = 1800

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
upsert_codex_top_level_setting service_tier "\"$CODEX_SERVICE_TIER\""
upsert_codex_top_level_setting approvals_reviewer "\"$CODEX_APPROVALS_REVIEWER\""
upsert_codex_top_level_setting check_for_update_on_startup "$(toml_bool "$CODEX_CHECK_FOR_UPDATE_ON_STARTUP")"
upsert_codex_table_setting agents max_threads "$CODEX_AGENTS_MAX_THREADS"
upsert_codex_table_setting agents max_depth "$CODEX_AGENTS_MAX_DEPTH"
upsert_codex_table_setting agents job_max_runtime_seconds "$CODEX_AGENTS_JOB_MAX_RUNTIME_SECONDS"
upsert_codex_table_setting apps._default default_tools_approval_mode "\"$CODEX_APPS_DEFAULT_TOOLS_APPROVAL_MODE\""
upsert_codex_table_setting apps._default destructive_enabled "$(toml_bool "$CODEX_APPS_DESTRUCTIVE_ENABLED")"
upsert_codex_table_setting apps._default open_world_enabled "$(toml_bool "$CODEX_APPS_OPEN_WORLD_ENABLED")"
upsert_codex_table_setting apps._default approvals_reviewer "\"$CODEX_APPROVALS_REVIEWER\""

remove_codex_unsafe_shell_wrapper_rules
remove_codex_unsafe_system_mutator_rules

ensure_codex_prefix_rule '["git"]' 'prefix_rule(
    pattern = ["git"],
    decision = "allow",
    justification = "Allow local Git workflows in trusted workspaces without repeated prompts",
    match = ["git status --short"],
    not_match = ["git-lfs status"],
)'
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
ensure_codex_prefix_rule '["uv", "run"]' 'prefix_rule(
    pattern = ["uv", "run"],
    decision = "allow",
    justification = "Allow uv run project commands in trusted workspaces without repeated prompts",
    match = ["uv run python -m pytest"],
    not_match = ["uvx ruff"],
)'

ensure_codex_prefix_rule '["git", "push"]' 'prefix_rule(
    pattern = ["git", "push"],
    decision = "prompt",
    justification = "Prompt before publishing commits to a remote repository",
    match = ["git push"],
)'
ensure_codex_prefix_rule '["git", "reset", "--hard"]' 'prefix_rule(
    pattern = ["git", "reset", "--hard"],
    decision = "prompt",
    justification = "Prompt before discarding tracked workspace changes",
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
ensure_codex_prefix_rule '["sudo"]' 'prefix_rule(
    pattern = ["sudo"],
    decision = "prompt",
    justification = "Prompt before running commands with elevated privileges",
    match = ["sudo softwareupdate --install --all"],
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
    decision = "prompt",
    justification = "Prompt before installing Homebrew packages",
    match = ["brew install ripgrep"],
)'
ensure_codex_prefix_rule '["brew", "upgrade"]' 'prefix_rule(
    pattern = ["brew", "upgrade"],
    decision = "prompt",
    justification = "Prompt before upgrading Homebrew packages",
    match = ["brew upgrade"],
)'
ensure_codex_prefix_rule '["rustup"]' 'prefix_rule(
    pattern = ["rustup"],
    decision = "prompt",
    justification = "Prompt before modifying Rust toolchains or global components",
    match = ["rustup update stable"],
)'
ensure_codex_prefix_rule '["cargo", "install"]' 'prefix_rule(
    pattern = ["cargo", "install"],
    decision = "prompt",
    justification = "Prompt before installing or replacing global Cargo binaries",
    match = ["cargo install cargo-nextest"],
)'
ensure_codex_prefix_rule '["uv", "tool", "install"]' 'prefix_rule(
    pattern = ["uv", "tool", "install"],
    decision = "prompt",
    justification = "Prompt before installing global uv tools",
    match = ["uv tool install ruff"],
)'
ensure_codex_prefix_rule '["uv", "tool", "upgrade"]' 'prefix_rule(
    pattern = ["uv", "tool", "upgrade"],
    decision = "prompt",
    justification = "Prompt before upgrading global uv tools",
    match = ["uv tool upgrade ruff"],
)'
ensure_codex_prefix_rule '["npm", "install", "-g"]' 'prefix_rule(
    pattern = ["npm", "install", "-g"],
    decision = "prompt",
    justification = "Prompt before installing or replacing global npm packages",
    match = ["npm install -g @openai/codex"],
)'
ensure_codex_prefix_rule '["npm", "install", "--global"]' 'prefix_rule(
    pattern = ["npm", "install", "--global"],
    decision = "prompt",
    justification = "Prompt before installing or replacing global npm packages",
    match = ["npm install --global @openai/codex"],
)'
ensure_codex_prefix_rule '["python", "-m", "pip", "install"]' 'prefix_rule(
    pattern = ["python", "-m", "pip", "install"],
    decision = "prompt",
    justification = "Prompt before installing packages into the active Python environment",
    match = ["python -m pip install pytest"],
)'
ensure_codex_prefix_rule '["python3", "-m", "pip", "install"]' 'prefix_rule(
    pattern = ["python3", "-m", "pip", "install"],
    decision = "prompt",
    justification = "Prompt before installing packages into the active Python environment",
    match = ["python3 -m pip install pytest"],
)'
ensure_codex_prefix_rule '["pipx", "install"]' 'prefix_rule(
    pattern = ["pipx", "install"],
    decision = "prompt",
    justification = "Prompt before installing global pipx applications",
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
ensure_codex_permissions_example

desired_mcp_servers=()
while IFS= read -r server_name; do
  if ! array_contains "$server_name" "${desired_mcp_servers[@]}"; then
    desired_mcp_servers+=("$server_name")
  fi
done < <(split_csv "$CODEX_MCP_ALLOWLIST")

if [[ "$CODEX_GITHUB_MCP_ENABLED" -eq 1 || -n "$GITHUB_TOKEN" ]]; then
  if ! array_contains github "${desired_mcp_servers[@]}"; then
    desired_mcp_servers+=(github)
  fi
fi
if [[ "$CODEX_SERENA_ENABLED" -eq 1 ]]; then
  if ! array_contains serena "${desired_mcp_servers[@]}"; then
    desired_mcp_servers+=(serena)
  fi
fi

if [[ -n "$GITHUB_TOKEN" ]]; then
  export "$CODEX_GITHUB_TOKEN_ENV_VAR=$GITHUB_TOKEN"
  write_warn "GitHub token exported in current shell for Codex MCP setup."
fi

existing_mcp_servers=()
if [[ -f "$config_toml" ]]; then
  while IFS= read -r server_name; do
    if ! array_contains "$server_name" "${existing_mcp_servers[@]}"; then
      existing_mcp_servers+=("$server_name")
    fi
  done < <(sed -nE 's/^\[mcp_servers\.([^].]+)\]$/\1/p' "$config_toml")
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
if array_contains memory "${desired_mcp_servers[@]}"; then
  memory_dir="$HOME/.local/share/codex"
  mkdir -p "$memory_dir"
  memory_file="$memory_dir/memory.jsonl"
  add_codex_mcp_if_missing memory codex mcp add memory --env "MEMORY_FILE_PATH=$memory_file" -- npx -y @modelcontextprotocol/server-memory
fi
if array_contains fetch "${desired_mcp_servers[@]}"; then
  if command_exists uvx; then
    add_codex_mcp_if_missing fetch codex mcp add fetch -- uvx mcp-server-fetch
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

upsert_codex_mcp_setting context7 startup_timeout_sec 30
upsert_codex_mcp_setting openaiDeveloperDocs startup_timeout_sec 30
upsert_codex_mcp_setting fetch default_tools_approval_mode "\"$CODEX_FETCH_MCP_APPROVAL_MODE\""
upsert_codex_mcp_setting github default_tools_approval_mode "\"$CODEX_GITHUB_MCP_APPROVAL_MODE\""
upsert_codex_mcp_setting serena default_tools_approval_mode "\"$CODEX_SERENA_MCP_APPROVAL_MODE\""

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
