write_step "Installing UEFI, QEMU, and firmware tooling..."

uefi_formulas=(
  nasm
  qemu
  llvm
  mtools
  dosfstools
  acpica
  bloaty
)

for formula in "${uefi_formulas[@]}"; do
  install_brew_formula_optional "$formula"
done

if command_exists uv; then
  install_uv_tool binwalk
else
  write_warn "uv is not available. Run python module first to install binwalk."
fi
