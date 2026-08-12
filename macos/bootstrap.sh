#!/usr/bin/env bash
set -eo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This bootstrap is only supported on macOS." >&2
  exit 1
fi

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_ROOT/.." && pwd)"

detect_git_user_name() {
  git config --global user.name 2>/dev/null || true
}

detect_git_user_email() {
  git config --global user.email 2>/dev/null || true
}

detect_astronvim_repo() {
  local nvim_dir="$HOME/.config/nvim"
  if [[ -d "$nvim_dir/.git" ]]; then
    git -C "$nvim_dir" remote get-url origin 2>/dev/null || true
  fi
}

USER_EMAIL="${USER_EMAIL:-$(detect_git_user_email)}"
GIT_USER_NAME="${GIT_USER_NAME:-$(detect_git_user_name)}"
NODE_VERSION="${NODE_VERSION:-lts/*}"
NVM_VERSION="${NVM_VERSION:-v0.40.4}"
ASTRONVIM_REPO="${ASTRONVIM_REPO:-$(detect_astronvim_repo)}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
FORCE_NEOVIM_CLEANUP="${FORCE_NEOVIM_CLEANUP:-0}"
MODULES_CSV="${MODULES_CSV:-}"

CODEX_MCP_ALLOWLIST="${CODEX_MCP_ALLOWLIST:-context7,openaiDeveloperDocs,microsoft-learn,memory,fetch,sequential-thinking}"
CODEX_MCP_DEFAULT_DISABLED_SERVERS="${CODEX_MCP_DEFAULT_DISABLED_SERVERS:-memory,fetch,sequential-thinking}"
CODEX_MCP_PRUNE_UNMANAGED="${CODEX_MCP_PRUNE_UNMANAGED:-0}"
CODEX_GITHUB_MCP_ENABLED="${CODEX_GITHUB_MCP_ENABLED:-0}"
CODEX_GITHUB_TOKEN_ENV_VAR="${CODEX_GITHUB_TOKEN_ENV_VAR:-GITHUB_PERSONAL_ACCESS_TOKEN}"
CODEX_SERENA_ENABLED="${CODEX_SERENA_ENABLED:-0}"
CODEX_PLAYWRIGHT_MCP_ENABLED="${CODEX_PLAYWRIGHT_MCP_ENABLED:-0}"
CODEX_SANDBOX_MODE="${CODEX_SANDBOX_MODE:-workspace-write}"
CODEX_APPROVAL_POLICY="${CODEX_APPROVAL_POLICY:-on-request}"
CODEX_APPROVALS_REVIEWER="${CODEX_APPROVALS_REVIEWER:-user}"
CODEX_CHECK_FOR_UPDATE_ON_STARTUP="${CODEX_CHECK_FOR_UPDATE_ON_STARTUP:-1}"
CODEX_MODEL="${CODEX_MODEL:-gpt-5.6-terra}"
CODEX_MODEL_REASONING_EFFORT="${CODEX_MODEL_REASONING_EFFORT:-medium}"
CODEX_MODEL_VERBOSITY="${CODEX_MODEL_VERBOSITY:-low}"
CODEX_SERVICE_TIER="${CODEX_SERVICE_TIER:-default}"
CODEX_APPS_DEFAULT_TOOLS_APPROVAL_MODE="${CODEX_APPS_DEFAULT_TOOLS_APPROVAL_MODE:-writes}"
CODEX_APPS_DESTRUCTIVE_ENABLED="${CODEX_APPS_DESTRUCTIVE_ENABLED:-0}"
CODEX_APPS_OPEN_WORLD_ENABLED="${CODEX_APPS_OPEN_WORLD_ENABLED:-0}"
CODEX_FETCH_MCP_APPROVAL_MODE="${CODEX_FETCH_MCP_APPROVAL_MODE:-prompt}"
CODEX_MICROSOFT_LEARN_MCP_APPROVAL_MODE="${CODEX_MICROSOFT_LEARN_MCP_APPROVAL_MODE:-writes}"
CODEX_GITHUB_MCP_APPROVAL_MODE="${CODEX_GITHUB_MCP_APPROVAL_MODE:-writes}"
CODEX_SERENA_MCP_APPROVAL_MODE="${CODEX_SERENA_MCP_APPROVAL_MODE:-writes}"
CODEX_PLAYWRIGHT_MCP_APPROVAL_MODE="${CODEX_PLAYWRIGHT_MCP_APPROVAL_MODE:-prompt}"
CODEX_PRUNE_DISABLED_OPTIONAL_MCP="${CODEX_PRUNE_DISABLED_OPTIONAL_MCP:-1}"
CODEX_PROFILES_ENABLED="${CODEX_PROFILES_ENABLED:-1}"
CODEX_LEAN_PROFILE_MODEL="${CODEX_LEAN_PROFILE_MODEL:-gpt-5.6-terra}"
CODEX_LEAN_PROFILE_REASONING_EFFORT="${CODEX_LEAN_PROFILE_REASONING_EFFORT:-medium}"
CODEX_LEAN_PROFILE_VERBOSITY="${CODEX_LEAN_PROFILE_VERBOSITY:-low}"
CODEX_DEEP_PROFILE_MODEL="${CODEX_DEEP_PROFILE_MODEL:-gpt-5.6-sol}"
CODEX_DEEP_PROFILE_REASONING_EFFORT="${CODEX_DEEP_PROFILE_REASONING_EFFORT:-high}"
CODEX_DEEP_PROFILE_VERBOSITY="${CODEX_DEEP_PROFILE_VERBOSITY:-medium}"
CODEX_CUSTOM_AGENTS_ENABLED="${CODEX_CUSTOM_AGENTS_ENABLED:-1}"
CODEX_CUSTOM_AGENTS="${CODEX_CUSTOM_AGENTS:-explorer-terra,reviewer-deep,docs-researcher,tester-terra,architect-deep,knowledge-curator,improvement-researcher}"
CODEX_AGENT_TEAMWORK_SKILL_ENABLED="${CODEX_AGENT_TEAMWORK_SKILL_ENABLED:-1}"
CODEX_GLOBAL_AGENTS_GUIDANCE_ENABLED="${CODEX_GLOBAL_AGENTS_GUIDANCE_ENABLED:-1}"
CODEX_UPDATE_ENABLED="${CODEX_UPDATE_ENABLED:-0}"
CODEX_CURATED_SKILLS="${CODEX_CURATED_SKILLS:-cli-creator,jupyter-notebook,pdf,playwright,security-best-practices,winui-app}"
CODEX_SUPERPOWERS_SKILLS="${CODEX_SUPERPOWERS_SKILLS:-systematic-debugging,verification-before-completion,test-driven-development,receiving-code-review,requesting-code-review,writing-skills}"
CODEX_KARPATHY_SKILLS="${CODEX_KARPATHY_SKILLS:-karpathy-guidelines}"
CODEX_CLAUDE_SKILLS="${CODEX_CLAUDE_SKILLS:-cpp-pro,rust-engineer,python-pro,pandas-pro,ml-pipeline,fine-tuning-expert,database-optimizer,sql-pro,mcp-developer,api-designer,code-documenter,devops-engineer,legacy-modernizer,secure-code-guardian,security-reviewer,spec-miner}"
CODEX_TIMESFM_SKILL_ENABLED="${CODEX_TIMESFM_SKILL_ENABLED:-0}"
CODEX_TIMESFM_SKILL_REPO="${CODEX_TIMESFM_SKILL_REPO:-https://github.com/google-research/timesfm.git}"
CODEX_TIMESFM_SKILL_PATH="${CODEX_TIMESFM_SKILL_PATH:-timesfm-forecasting}"
CODEX_REMOVE_LEGACY_EXTERNAL_SKILL_SOURCES="${CODEX_REMOVE_LEGACY_EXTERNAL_SKILL_SOURCES:-0}"

CLEANUP_DRY_RUN="${CLEANUP_DRY_RUN:-0}"
CLEANUP_PRUNE_DAYS="${CLEANUP_PRUNE_DAYS:-30}"
CLEANUP_INCLUDE_USER_CACHES="${CLEANUP_INCLUDE_USER_CACHES:-0}"

ML_PYTHON_VERSION="${ML_PYTHON_VERSION:-3.12}"
ML_ENVIRONMENT_PATH="${ML_ENVIRONMENT_PATH:-$HOME/.virtualenvs/firstboot-ml}"
ML_PYTHON_PACKAGES="${ML_PYTHON_PACKAGES:-numpy,pandas,polars,duckdb,scikit-learn,matplotlib,seaborn,jupyterlab,ipykernel,ipywidgets,mlflow,optuna,xgboost,pyarrow,tqdm}"
ML_TIMESFM_ENABLED="${ML_TIMESFM_ENABLED:-0}"
ML_TIMESFM_BACKEND="${ML_TIMESFM_BACKEND:-torch-default}"

DEFAULT_ASTRONVIM_REPO="https://github.com/fedorov7/astronvim-config-v4.git"
if [[ -z "$USER_EMAIL" ]]; then
  USER_EMAIL="your-email@example.com"
fi
if [[ -z "$GIT_USER_NAME" ]]; then
  GIT_USER_NAME="Your Name"
fi
if [[ -z "$ASTRONVIM_REPO" ]]; then
  ASTRONVIM_REPO="$DEFAULT_ASTRONVIM_REPO"
fi

write_step() { printf ":: %s\n" "$1"; }
write_ok() { printf "   OK: %s\n" "$1"; }
write_skip() { printf "   SKIP: %s\n" "$1"; }
write_warn() { printf "   WARN: %s\n" "$1"; }

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf "%s" "$value"
}

split_csv() {
  local csv="$1"
  local parts=()
  IFS=',' read -r -a parts <<<"$csv"
  local item
  for item in "${parts[@]}"; do
    item="$(trim "$item")"
    if [[ -n "$item" ]]; then
      printf "%s\n" "$item"
    fi
  done
}

array_contains() {
  local needle="$1"
  shift || true
  local item
  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

refresh_path() {
  local path_entries=(
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
    "/usr/local/bin"
    "/usr/local/sbin"
    "$HOME/.cargo/bin"
    "$HOME/.local/bin"
  )
  local existing_entries=()
  local new_path_entries=()
  local entry
  local existing_entry

  IFS=':' read -r -a existing_entries <<<"$PATH"
  for entry in "${path_entries[@]}"; do
    if [[ -d "$entry" ]]; then
      new_path_entries+=("$entry")
    fi
  done

  for existing_entry in "${existing_entries[@]}"; do
    if [[ -n "$existing_entry" ]] && ! array_contains "$existing_entry" "${new_path_entries[@]}"; then
      new_path_entries+=("$existing_entry")
    fi
  done
  PATH="$(IFS=:; printf "%s" "${new_path_entries[*]}")"
  export PATH
}

ensure_homebrew() {
  if command_exists brew; then
    return
  fi
  write_step "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  refresh_path
  write_ok "Homebrew installed"
}

install_brew_formula() {
  local formula="$1"
  local name="${2:-$formula}"
  ensure_homebrew
  if brew list --formula "$formula" >/dev/null 2>&1; then
    write_skip "$name already installed"
    return
  fi
  write_step "Installing $name..."
  brew install "$formula"
  write_ok "$name installed"
}

install_brew_formula_optional() {
  local formula="$1"
  local name="${2:-$formula}"
  ensure_homebrew
  if ! brew info --formula "$formula" >/dev/null 2>&1; then
    write_warn "$name formula unavailable in Homebrew. Skipping."
    return
  fi
  if brew list --formula "$formula" >/dev/null 2>&1; then
    write_skip "$name already installed"
    return
  fi
  write_step "Installing $name..."
  if brew install "$formula"; then
    write_ok "$name installed"
  else
    write_warn "Failed to install $name. Continuing."
  fi
}

load_nvm() {
  export NVM_DIR="$HOME/.nvm"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh"
  fi
  if [[ -s "$NVM_DIR/bash_completion" ]]; then
    # shellcheck source=/dev/null
    . "$NVM_DIR/bash_completion"
  fi
}

backup_file_if_exists() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    local backup="${target}.backup.$(date +%Y%m%d-%H%M%S)"
    cp -R "$target" "$backup"
    write_ok "Backup created: $backup"
  fi
}

deploy_file() {
  local source="$1"
  local destination="$2"
  local destination_dir
  destination_dir="$(dirname "$destination")"
  mkdir -p "$destination_dir"
  backup_file_if_exists "$destination"
  cp "$source" "$destination"
  write_ok "Deployed $(basename "$destination") to $destination"
}

set_git_config_if_needed() {
  local key="$1"
  local value="$2"
  local current
  current="$(git config --global "$key" 2>/dev/null || true)"
  if [[ "$current" == "$value" ]]; then
    write_skip "git config $key already set"
    return
  fi
  git config --global "$key" "$value"
  write_ok "git config $key = $value"
}

install_cargo_binary() {
  local command_name="$1"
  local package_name="$2"
  shift 2
  local install_args=("$@")
  if command_exists "$command_name"; then
    write_skip "$command_name already available"
    return
  fi
  if ! command_exists cargo; then
    write_warn "cargo not available. Run rust module first to install $package_name."
    return
  fi
  local args_text=""
  if [[ ${#install_args[@]} -gt 0 ]]; then
    args_text=" ${install_args[*]}"
  fi
  write_step "Installing $package_name via cargo$args_text..."
  cargo install "$package_name" "${install_args[@]}"
  write_ok "$package_name installed"
}

install_uv_tool() {
  local command_name="$1"
  local package_name="${2:-$command_name}"
  if command_exists "$command_name"; then
    write_skip "$command_name already available"
    return
  fi
  if ! command_exists uv; then
    write_warn "uv not available. Run python module first to install $package_name."
    return
  fi
  write_step "Installing $package_name via uv tool..."
  uv tool install "$package_name"
  write_ok "$package_name installed"
}

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh [options]

Options:
  --modules <csv>                       Comma-separated module list to run.
  --user-email <email>                  Git/SSH email identity.
  --git-user-name <name>                Git user.name.
  --node-version <value>                Node.js version target for nvm (default: lts/*).
  --nvm-version <tag>                   nvm installer version (default: v0.40.4).
  --astronvim-repo <url>                Neovim config repository URL.
  --github-token <token>                Legacy input; MCP tokens are not written to config.
  --force-neovim-cleanup                Remove Neovim config/data before clone/update.
  --preserve-neovim-state               Preserve Neovim state unless stale non-git config blocks cloning.
  --codex-mcp-allowlist <csv>           Codex MCP allowlist.
  --codex-mcp-default-disabled-servers <csv> MCP servers enabled only by the deep profile.
  --codex-mcp-prune-unmanaged           Remove Codex MCP entries not in allowlist.
  --codex-github-mcp-enabled            Enable official GitHub MCP server for Codex.
  --codex-github-token-env-var <name>   Env var name used by Codex GitHub MCP.
  --codex-serena-enabled                Enable Serena MCP via uvx.
  --codex-playwright-mcp-enabled        Enable Playwright MCP browser automation.
  --codex-sandbox-mode <mode>           Codex sandbox mode (default: workspace-write).
  --codex-approval-policy <policy>      Codex approval policy (default: on-request).
  --codex-model <model>                 Codex model (default: gpt-5.6-terra).
  --codex-model-reasoning-effort <effort> Codex reasoning effort (default: medium).
  --codex-model-verbosity <level>       Codex response verbosity (default: low).
  --codex-service-tier <tier>           Codex service tier (default: default).
  --codex-apps-default-tools-approval-mode <mode> App tool approval mode (default: writes).
  --codex-microsoft-learn-mcp-approval-mode <mode> Microsoft Learn MCP approval mode (default: writes).
  --codex-playwright-mcp-approval-mode <mode> Playwright MCP approval mode (default: prompt).
  --codex-prune-disabled-optional-mcp Remove disabled optional MCP servers managed by this script (default).
  --codex-keep-disabled-optional-mcp  Keep disabled optional MCP servers if already configured.
  --codex-profiles-enabled            Create lean/deep Codex CLI profile files (default).
  --codex-profiles-disabled           Remove managed lean/deep Codex CLI profile files.
  --codex-lean-profile-model <model>  Model for the lean Codex profile.
  --codex-lean-profile-reasoning-effort <effort> Reasoning effort for the lean Codex profile.
  --codex-lean-profile-verbosity <level> Response verbosity for the lean profile.
  --codex-deep-profile-model <model>  Model for the deep Codex profile.
  --codex-deep-profile-reasoning-effort <effort> Reasoning effort for the deep profile.
  --codex-deep-profile-verbosity <level> Response verbosity for the deep profile.
  --codex-custom-agents-enabled       Create curated Codex custom agents (default).
  --codex-custom-agents-disabled      Remove curated Codex custom agents.
  --codex-custom-agents <csv>         Curated Codex custom agent allowlist.
  --codex-agent-teamwork-skill-enabled  Install managed Codex teamwork skill (default).
  --codex-agent-teamwork-skill-disabled Remove managed Codex teamwork skill.
  --codex-global-agents-guidance-enabled  Write global AGENTS.md teamwork guidance (default).
  --codex-global-agents-guidance-disabled Remove global AGENTS.md teamwork guidance.
  --codex-curated-skills <csv>          Curated Codex skills allowlist.
  --codex-superpowers-skills <csv>      superpowers skill allowlist.
  --codex-karpathy-skills <csv>         karpathy skill allowlist.
  --codex-claude-skills <csv>           claude-skills allowlist.
  --codex-timesfm-skill-enabled         Enable TimesFM skill sync.
  --codex-timesfm-skill-repo <url>      TimesFM skill source repository.
  --codex-timesfm-skill-path <path>     Relative path to SKILL.md in TimesFM repo.
  --codex-remove-legacy-skill-sources   Remove legacy ~/.codex skill source directories.
  --cleanup-dry-run                     Show cleanup actions without deleting files.
  --cleanup-apply                       Delete cleanup targets (default).
  --cleanup-prune-days <days>           Age threshold for user cache cleanup (default: 30).
  --cleanup-include-user-caches         Prune aged ~/.cache and ~/Library/Caches entries.
  --cleanup-skip-user-caches            Skip user cache cleanup (default).
  --ml-python-version <version>         Python version for ML environment.
  --ml-environment-path <path>          ML virtual environment path.
  --ml-python-packages <csv>            ML package allowlist for uv pip install.
  --ml-timesfm-enabled                  Install TimesFM runtime in ML environment.
  --ml-timesfm-backend <backend>        torch-default, torch-cpu, or flax.
  -h, --help                            Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --modules) MODULES_CSV="$2"; shift 2 ;;
    --user-email) USER_EMAIL="$2"; shift 2 ;;
    --git-user-name) GIT_USER_NAME="$2"; shift 2 ;;
    --node-version) NODE_VERSION="$2"; shift 2 ;;
    --nvm-version) NVM_VERSION="$2"; shift 2 ;;
    --astronvim-repo) ASTRONVIM_REPO="$2"; shift 2 ;;
    --github-token) GITHUB_TOKEN="$2"; shift 2 ;;
    --force-neovim-cleanup) FORCE_NEOVIM_CLEANUP=1; shift ;;
    --preserve-neovim-state) FORCE_NEOVIM_CLEANUP=0; shift ;;
    --codex-mcp-allowlist) CODEX_MCP_ALLOWLIST="$2"; shift 2 ;;
    --codex-mcp-default-disabled-servers) CODEX_MCP_DEFAULT_DISABLED_SERVERS="$2"; shift 2 ;;
    --codex-mcp-prune-unmanaged) CODEX_MCP_PRUNE_UNMANAGED=1; shift ;;
    --codex-github-mcp-enabled) CODEX_GITHUB_MCP_ENABLED=1; shift ;;
    --codex-github-token-env-var) CODEX_GITHUB_TOKEN_ENV_VAR="$2"; shift 2 ;;
    --codex-serena-enabled) CODEX_SERENA_ENABLED=1; shift ;;
    --codex-playwright-mcp-enabled) CODEX_PLAYWRIGHT_MCP_ENABLED=1; shift ;;
    --codex-sandbox-mode) CODEX_SANDBOX_MODE="$2"; shift 2 ;;
    --codex-approval-policy) CODEX_APPROVAL_POLICY="$2"; shift 2 ;;
    --codex-model) CODEX_MODEL="$2"; shift 2 ;;
    --codex-model-reasoning-effort) CODEX_MODEL_REASONING_EFFORT="$2"; shift 2 ;;
    --codex-model-verbosity) CODEX_MODEL_VERBOSITY="$2"; shift 2 ;;
    --codex-service-tier) CODEX_SERVICE_TIER="$2"; shift 2 ;;
    --codex-apps-default-tools-approval-mode) CODEX_APPS_DEFAULT_TOOLS_APPROVAL_MODE="$2"; shift 2 ;;
    --codex-microsoft-learn-mcp-approval-mode) CODEX_MICROSOFT_LEARN_MCP_APPROVAL_MODE="$2"; shift 2 ;;
    --codex-playwright-mcp-approval-mode) CODEX_PLAYWRIGHT_MCP_APPROVAL_MODE="$2"; shift 2 ;;
    --codex-prune-disabled-optional-mcp) CODEX_PRUNE_DISABLED_OPTIONAL_MCP=1; shift ;;
    --codex-keep-disabled-optional-mcp) CODEX_PRUNE_DISABLED_OPTIONAL_MCP=0; shift ;;
    --codex-profiles-enabled) CODEX_PROFILES_ENABLED=1; shift ;;
    --codex-profiles-disabled) CODEX_PROFILES_ENABLED=0; shift ;;
    --codex-lean-profile-model) CODEX_LEAN_PROFILE_MODEL="$2"; shift 2 ;;
    --codex-lean-profile-reasoning-effort) CODEX_LEAN_PROFILE_REASONING_EFFORT="$2"; shift 2 ;;
    --codex-lean-profile-verbosity) CODEX_LEAN_PROFILE_VERBOSITY="$2"; shift 2 ;;
    --codex-deep-profile-model) CODEX_DEEP_PROFILE_MODEL="$2"; shift 2 ;;
    --codex-deep-profile-reasoning-effort) CODEX_DEEP_PROFILE_REASONING_EFFORT="$2"; shift 2 ;;
    --codex-deep-profile-verbosity) CODEX_DEEP_PROFILE_VERBOSITY="$2"; shift 2 ;;
    --codex-custom-agents-enabled) CODEX_CUSTOM_AGENTS_ENABLED=1; shift ;;
    --codex-custom-agents-disabled) CODEX_CUSTOM_AGENTS_ENABLED=0; shift ;;
    --codex-custom-agents) CODEX_CUSTOM_AGENTS="$2"; shift 2 ;;
    --codex-agent-teamwork-skill-enabled) CODEX_AGENT_TEAMWORK_SKILL_ENABLED=1; shift ;;
    --codex-agent-teamwork-skill-disabled) CODEX_AGENT_TEAMWORK_SKILL_ENABLED=0; shift ;;
    --codex-global-agents-guidance-enabled) CODEX_GLOBAL_AGENTS_GUIDANCE_ENABLED=1; shift ;;
    --codex-global-agents-guidance-disabled) CODEX_GLOBAL_AGENTS_GUIDANCE_ENABLED=0; shift ;;
    --codex-curated-skills) CODEX_CURATED_SKILLS="$2"; shift 2 ;;
    --codex-superpowers-skills) CODEX_SUPERPOWERS_SKILLS="$2"; shift 2 ;;
    --codex-karpathy-skills) CODEX_KARPATHY_SKILLS="$2"; shift 2 ;;
    --codex-claude-skills) CODEX_CLAUDE_SKILLS="$2"; shift 2 ;;
    --codex-timesfm-skill-enabled) CODEX_TIMESFM_SKILL_ENABLED=1; shift ;;
    --codex-timesfm-skill-repo) CODEX_TIMESFM_SKILL_REPO="$2"; shift 2 ;;
    --codex-timesfm-skill-path) CODEX_TIMESFM_SKILL_PATH="$2"; shift 2 ;;
    --codex-remove-legacy-skill-sources) CODEX_REMOVE_LEGACY_EXTERNAL_SKILL_SOURCES=1; shift ;;
    --cleanup-dry-run) CLEANUP_DRY_RUN=1; shift ;;
    --cleanup-apply) CLEANUP_DRY_RUN=0; shift ;;
    --cleanup-prune-days) CLEANUP_PRUNE_DAYS="$2"; shift 2 ;;
    --cleanup-include-user-caches) CLEANUP_INCLUDE_USER_CACHES=1; shift ;;
    --cleanup-skip-user-caches) CLEANUP_INCLUDE_USER_CACHES=0; shift ;;
    --ml-python-version) ML_PYTHON_VERSION="$2"; shift 2 ;;
    --ml-environment-path) ML_ENVIRONMENT_PATH="$2"; shift 2 ;;
    --ml-python-packages) ML_PYTHON_PACKAGES="$2"; shift 2 ;;
    --ml-timesfm-enabled) ML_TIMESFM_ENABLED=1; shift ;;
    --ml-timesfm-backend) ML_TIMESFM_BACKEND="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

refresh_path
ensure_homebrew

ALL_MODULES=(
  base
  shell
  ssh
  neovim
  nodejs
  python
  rust
  cpp
  lua
  ml
  cli_tools
  codex
  claude
  cleanup
  embedded
  uefi
  security_tools
)

DEFAULT_MODULES=(
  base
  shell
  ssh
  neovim
  nodejs
  python
  rust
  cpp
  cli_tools
  codex
)

SELECTED_MODULES=()
if [[ -z "$MODULES_CSV" ]]; then
  SELECTED_MODULES=("${DEFAULT_MODULES[@]}")
else
  while IFS= read -r module_name; do
    SELECTED_MODULES+=("$module_name")
  done < <(split_csv "$MODULES_CSV")
fi

for module_name in "${SELECTED_MODULES[@]}"; do
  if ! array_contains "$module_name" "${ALL_MODULES[@]}"; then
    write_warn "Unknown module: $module_name"
    continue
  fi

  module_path="$SCRIPT_ROOT/modules/${module_name}.sh"
  if [[ ! -f "$module_path" ]]; then
    write_warn "Module not found: $module_path"
    continue
  fi

  echo ""
  printf "═══ Module: %s ═══\n" "$module_name"
  # shellcheck source=/dev/null
  . "$module_path"

  if [[ "$module_name" == "nodejs" ]]; then
    load_nvm
  fi
done

echo ""
echo "═══ Bootstrap complete ═══"
