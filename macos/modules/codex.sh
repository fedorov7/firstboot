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
  local current_block
  current_block="$(sed -n "/^\[mcp_servers\.${name}\]/,/^\[mcp_servers\./p" "$config_toml" | sed '$ { /^\[mcp_servers\./d; }')"
  if [[ "$current_block" == *"$key = $value"* ]]; then
    write_skip "MCP $name $key already set"
    return
  fi
  local temp_config
  temp_config="$(mktemp)"
  awk -v section="[mcp_servers.${name}]" -v key="$key" -v value="$value" '
    BEGIN { in_section = 0; seen = 0 }
    $0 == section { in_section = 1; print; next }
    in_section && /^\[mcp_servers\./ {
      if (!seen) {
        print key " = " value
        seen = 1
      }
      in_section = 0
    }
    in_section && $0 ~ "^" key " = " {
      if (!seen) {
        print key " = " value
        seen = 1
      }
      next
    }
    { print }
    END {
      if (in_section && !seen) {
        print key " = " value
      }
    }
  ' "$config_toml" >"$temp_config"
  cp "$temp_config" "$config_toml"
  rm -f "$temp_config"
  write_ok "MCP $name $key = $value"
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

ensure_codex_permissions_example() {
  if [[ -f "$codex_permissions_example" ]]; then
    write_skip "Codex permissions example already present"
    return
  fi
  cat >"$codex_permissions_example" <<'EOF'
# Example only. Copy selected settings to ~/.codex/config.toml when needed.
sandbox_mode = "workspace-write"
approval_policy = "on-request"

[sandbox_workspace_write]
writable_roots = [
  "/home/alexander/example"
]
EOF
  write_ok "Codex permissions example created"
}

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
  done < <(sed -nE 's/^\[mcp_servers\.([^]]+)\]$/\1/p' "$config_toml")
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
upsert_codex_mcp_setting fetch default_tools_approval_mode '"prompt"'
upsert_codex_mcp_setting github default_tools_approval_mode '"prompt"'
upsert_codex_mcp_setting serena default_tools_approval_mode '"prompt"'

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
