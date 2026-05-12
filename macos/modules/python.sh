write_step "Setting up Python via uv..."

install_brew_formula uv
install_brew_formula ruff

if ! command_exists uv; then
  write_warn "uv not found in PATH after install. Restart shell and re-run."
  return
fi

if ! uv python list --installed 2>/dev/null | grep -q '3\.12'; then
  write_step "Installing Python 3.12 via uv..."
  uv python install 3.12
  write_ok "Python 3.12 installed"
else
  write_skip "Python 3.12 already installed"
fi

uv_tools=(
  pyright
  mypy
  black
  pytest
  pre-commit
  tox
  nox
  ipython
)

for tool in "${uv_tools[@]}"; do
  if command_exists "$tool"; then
    write_skip "$tool already available"
  else
    write_step "Installing $tool via uv tool..."
    uv tool install "$tool"
    write_ok "$tool installed"
  fi
done
