write_step "Setting up Claude CLI..."

load_nvm
if ! command_exists npm; then
  write_warn "npm not available. Run nodejs module first."
  return
fi

if ! command_exists claude; then
  write_step "Installing Claude CLI..."
  npm install -g @anthropic-ai/claude-code
  write_ok "Claude CLI installed"
else
  write_skip "Claude CLI already installed"
fi

claude_dir="$HOME/.claude"
mkdir -p "$claude_dir"

settings_source="$REPO_ROOT/roles/claude/files/settings.json"
settings_dest="$claude_dir/settings.json"
if [[ -f "$settings_source" ]]; then
  deploy_file "$settings_source" "$settings_dest"
else
  write_warn "settings.json source not found at $settings_source"
fi

claude_json="$HOME/.claude.json"

test_claude_mcp_configured() {
  local name="$1"
  if [[ ! -f "$claude_json" ]]; then
    return 1
  fi
  if command_exists jq; then
    jq -e --arg n "$name" '.mcpServers[$n]' "$claude_json" >/dev/null 2>&1
    return $?
  fi
  grep -q "\"$name\"" "$claude_json"
}

add_claude_mcp_if_missing() {
  local name="$1"
  shift
  if test_claude_mcp_configured "$name"; then
    write_skip "MCP $name already configured"
    return
  fi
  "$@"
  write_ok "MCP $name added"
}

remove_claude_mcp_if_present() {
  local name="$1"
  if test_claude_mcp_configured "$name"; then
    claude mcp remove --scope user "$name"
    write_ok "Removed obsolete MCP: $name"
  fi
}

add_claude_mcp_if_missing context7 claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp

memory_dir="$HOME/.local/share/claude"
mkdir -p "$memory_dir"
memory_file="$memory_dir/memory.jsonl"
add_claude_mcp_if_missing memory claude mcp add --scope user memory -e "MEMORY_FILE_PATH=$memory_file" -- npx -y @modelcontextprotocol/server-memory

if command_exists uvx; then
  add_claude_mcp_if_missing fetch claude mcp add --scope user fetch -- uvx mcp-server-fetch
else
  write_warn "uvx not available. Run python module first to enable fetch MCP."
fi

add_claude_mcp_if_missing sequential-thinking claude mcp add --scope user sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking

if [[ -n "$GITHUB_TOKEN" ]]; then
  add_claude_mcp_if_missing github claude mcp add --scope user github -e "GITHUB_PERSONAL_ACCESS_TOKEN=$GITHUB_TOKEN" -- npx -y @modelcontextprotocol/server-github
fi

remove_claude_mcp_if_present sentry
remove_claude_mcp_if_present playwright

marketplace_names=(
  claude-plugins-official
  superpowers-dev
  fullstack-dev-skills
)
marketplace_sources=(
  anthropics/claude-plugins-official
  https://github.com/obra/superpowers
  https://github.com/Jeffallan/claude-skills
)

for i in "${!marketplace_names[@]}"; do
  name="${marketplace_names[$i]}"
  source_ref="${marketplace_sources[$i]}"
  marketplace_dir="$claude_dir/plugins/marketplaces/$name"
  if [[ ! -d "$marketplace_dir" ]]; then
    write_step "Adding marketplace: $name..."
    claude plugin marketplace add "$source_ref"
    write_ok "Marketplace $name added"
  else
    write_skip "Marketplace $name already installed"
  fi
done

plugins=(
  superpowers@claude-plugins-official
  context-engineering-fundamentals@context-engineering-marketplace
  agent-architecture@context-engineering-marketplace
  agent-evaluation@context-engineering-marketplace
  agent-development@context-engineering-marketplace
  cognitive-architecture@context-engineering-marketplace
  fullstack-dev-skills@fullstack-dev-skills
  clangd-lsp@claude-plugins-official
  pyright-lsp@claude-plugins-official
)

for plugin in "${plugins[@]}"; do
  output="$(claude plugin enable "$plugin" 2>&1 || true)"
  if [[ "$output" == *"already enabled"* ]]; then
    write_skip "Plugin $plugin already enabled"
  elif [[ "$output" == *"enabled"* ]]; then
    write_ok "Plugin $plugin enabled"
  else
    write_warn "Failed to enable plugin $plugin: $output"
  fi
done
