write_step "Installing CLI tools..."

cli_formulas=(
  git-delta
  hyperfine
  just
  tokei
  lazygit
  dust
  difftastic
)

for formula in "${cli_formulas[@]}"; do
  install_brew_formula "$formula"
done

install_cargo_binary watchexec watchexec-cli --locked
