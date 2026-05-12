write_step "Installing embedded systems tooling..."

embedded_formulas=(
  openocd
  dfu-util
  gperf
  picocom
)

for formula in "${embedded_formulas[@]}"; do
  install_brew_formula_optional "$formula"
done

install_cargo_binary probe-rs probe-rs-tools

write_warn "USB/debug probe permissions and vendor drivers may require additional manual setup on macOS."
