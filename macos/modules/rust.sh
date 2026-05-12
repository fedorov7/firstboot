write_step "Setting up Rust..."

if ! command_exists rustup; then
  install_brew_formula rustup-init
  refresh_path
  if command_exists rustup-init && ! command_exists rustup; then
    write_step "Initializing rustup..."
    rustup-init -y --default-toolchain stable
    refresh_path
    write_ok "rustup initialized"
  fi
fi

if ! command_exists rustup; then
  write_warn "rustup is not available after install. Restart shell and re-run rust module."
  return
fi

default_toolchain="$(rustup default 2>/dev/null || true)"
if [[ "$default_toolchain" != *stable* ]]; then
  rustup default stable
  write_ok "Rust stable set as default"
else
  write_skip "Rust stable already default"
fi

installed_components="$(rustup component list --installed 2>/dev/null || true)"
for component in rust-analyzer clippy rustfmt; do
  if [[ "$installed_components" == *"$component"* ]]; then
    write_skip "Component $component already installed"
  else
    rustup component add "$component"
    write_ok "Component $component installed"
  fi
done

install_cargo_binary sccache sccache
install_cargo_binary cargo-add cargo-edit
install_cargo_binary cargo-watch cargo-watch
install_cargo_binary cargo-nextest cargo-nextest --locked
install_cargo_binary bacon bacon
install_cargo_binary taplo taplo-cli
