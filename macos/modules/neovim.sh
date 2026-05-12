write_step "Setting up Neovim..."

install_brew_formula neovim

nvim_config="$HOME/.config/nvim"
nvim_cleanup_paths=(
  "$nvim_config"
  "$HOME/.local/share/nvim"
  "$HOME/.local/state/nvim"
  "$HOME/.cache/nvim"
)

should_cleanup=0
if [[ "$FORCE_NEOVIM_CLEANUP" -eq 1 ]]; then
  should_cleanup=1
elif [[ -d "$nvim_config" && ! -d "$nvim_config/.git" ]]; then
  should_cleanup=1
fi

if [[ "$should_cleanup" -eq 1 ]]; then
  for path in "${nvim_cleanup_paths[@]}"; do
    if [[ -e "$path" ]]; then
      rm -rf "$path"
      write_ok "Removed stale Neovim path: $path"
    fi
  done
fi

if [[ ! -d "$nvim_config" ]]; then
  write_step "Cloning AstroNvim config..."
  git clone "$ASTRONVIM_REPO" "$nvim_config"
  write_ok "AstroNvim config cloned to $nvim_config"
elif [[ -d "$nvim_config/.git" ]]; then
  write_step "Updating AstroNvim config..."
  git -C "$nvim_config" pull --ff-only
  write_ok "AstroNvim config updated"
else
  write_warn "$nvim_config exists but is not a git repo. Skipping."
fi
