# shellcheck shell=bash

write_step "Cleaning stale macOS provisioning files..."

cleanup_prune_cache_dir() {
  local path="$1"
  local label="$2"

  if [[ ! -d "$path" ]]; then
    write_skip "$label not found"
    return
  fi

  write_step "Pruning $label files older than $CLEANUP_PRUNE_DAYS days..."
  if [[ "$CLEANUP_DRY_RUN" -eq 1 ]]; then
    find "$path" -mindepth 1 -prune -mtime +"$CLEANUP_PRUNE_DAYS" -print
    return
  fi
  find "$path" -mindepth 1 -prune -mtime +"$CLEANUP_PRUNE_DAYS" -exec rm -rf {} +
  write_ok "$label pruned"
}

if ! [[ "$CLEANUP_PRUNE_DAYS" =~ ^[0-9]+$ ]]; then
  write_warn "Invalid CLEANUP_PRUNE_DAYS=$CLEANUP_PRUNE_DAYS. Using 30."
  CLEANUP_PRUNE_DAYS=30
fi

ensure_homebrew

write_step "Cleaning Homebrew cache and old versions..."
if [[ "$CLEANUP_DRY_RUN" -eq 1 ]]; then
  brew cleanup --dry-run --prune=all
else
  brew cleanup --prune=all
fi

write_step "Removing unused Homebrew dependencies..."
if [[ "$CLEANUP_DRY_RUN" -eq 1 ]]; then
  write_skip "brew autoremove skipped in dry-run mode"
else
  brew autoremove
fi

if [[ "$CLEANUP_INCLUDE_USER_CACHES" -eq 1 ]]; then
  cleanup_prune_cache_dir "$HOME/Library/Caches/Homebrew" "Homebrew download cache"
  cleanup_prune_cache_dir "$HOME/.cache" "XDG user cache"
  cleanup_prune_cache_dir "${TMPDIR:-/tmp}/codex" "Codex temporary cache"
else
  write_skip "User cache cleanup disabled"
fi

write_step "Checking Homebrew dependency state..."
brew missing

write_step "Running brew doctor..."
brew doctor
