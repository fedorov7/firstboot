write_step "Installing Lua application development tooling..."

lua_formulas=(
  lua
  luajit
  lua-language-server
)

for formula in "${lua_formulas[@]}"; do
  install_brew_formula "$formula"
done

install_cargo_binary stylua stylua

write_warn "LuaRocks is not configured by this module. Install it manually if required by your projects."
