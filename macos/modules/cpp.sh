write_step "Setting up C++ toolchain..."

cpp_formulas=(
  cmake
  ninja
  llvm
  meson
  cppcheck
  doxygen
  graphviz
  ccache
  bear
  gcovr
  lcov
)

for formula in "${cpp_formulas[@]}"; do
  install_brew_formula "$formula"
done

if xcode-select -p >/dev/null 2>&1; then
  write_skip "Xcode Command Line Tools already configured"
else
  write_warn "Xcode Command Line Tools not configured. Run: xcode-select --install"
fi
