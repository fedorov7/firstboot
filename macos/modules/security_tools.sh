write_step "Installing local security and compliance tooling..."

security_formulas=(
  gitleaks
  trivy
  osv-scanner
)

for formula in "${security_formulas[@]}"; do
  install_brew_formula "$formula"
done

install_cargo_binary cargo-audit cargo-audit
install_cargo_binary cargo-deny cargo-deny

install_uv_tool flawfinder
install_uv_tool codespell
install_uv_tool reuse
