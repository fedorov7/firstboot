write_step "Configuring zsh shell environment..."

install_brew_formula antidote "zsh-antidote"
install_brew_formula zoxide

zshrc_source="$REPO_ROOT/macos/files/zshrc"
plugins_source="$REPO_ROOT/roles/zsh/files/zsh_plugins.txt"
p10k_source="$REPO_ROOT/roles/zsh/files/p10k.zsh"

if [[ ! -f "$zshrc_source" ]]; then
  write_warn "zshrc source not found: $zshrc_source"
else
  deploy_file "$zshrc_source" "$HOME/.zshrc"
fi

if [[ -f "$plugins_source" ]]; then
  deploy_file "$plugins_source" "$HOME/.zsh_plugins.txt"
else
  write_warn "zsh plugin list source not found: $plugins_source"
fi

if [[ -f "$p10k_source" ]]; then
  deploy_file "$p10k_source" "$HOME/.p10k.zsh"
else
  write_warn "p10k source not found: $p10k_source"
fi

current_shell="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}' || true)"
if [[ "$current_shell" != "/bin/zsh" ]]; then
  write_warn "Default shell is $current_shell. Run: chsh -s /bin/zsh"
else
  write_skip "Default shell already set to /bin/zsh"
fi
