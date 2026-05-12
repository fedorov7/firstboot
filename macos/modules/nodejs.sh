write_step "Setting up Node.js via nvm..."

if [[ ! -s "$HOME/.nvm/nvm.sh" ]]; then
  write_step "Installing nvm $NVM_VERSION..."
  PROFILE=/dev/null NVM_DIR="$HOME/.nvm" bash -c "$(curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh")"
  write_ok "nvm installed"
else
  write_skip "nvm already installed"
fi

load_nvm

if ! command_exists nvm; then
  write_warn "nvm is not available in current shell. Restart shell and re-run nodejs module."
  return
fi

if [[ -f "$HOME/.npmrc" ]]; then
  tmp_file="$(mktemp)"
  grep -Ev '^\s*(prefix|globalconfig)\s*=' "$HOME/.npmrc" >"$tmp_file" || true
  if ! cmp -s "$tmp_file" "$HOME/.npmrc"; then
    backup_file_if_exists "$HOME/.npmrc"
    mv "$tmp_file" "$HOME/.npmrc"
    write_ok "Removed incompatible npm prefix/globalconfig settings"
  else
    rm -f "$tmp_file"
    write_skip "No conflicting npm prefix/globalconfig settings"
  fi
fi

if ! nvm ls "$NODE_VERSION" >/dev/null 2>&1; then
  write_step "Installing Node.js $NODE_VERSION via nvm..."
  nvm install "$NODE_VERSION"
  write_ok "Node.js $NODE_VERSION installed"
else
  write_skip "Node.js $NODE_VERSION already installed in nvm"
fi

nvm alias default "$NODE_VERSION" >/dev/null
nvm use "$NODE_VERSION" >/dev/null
write_ok "Node.js $NODE_VERSION set as default"

if brew list --formula node >/dev/null 2>&1; then
  write_warn "Homebrew node formula detected. Consider removing it to avoid conflicts with nvm."
fi
