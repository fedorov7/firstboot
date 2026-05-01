Write-Step "Installing Lua application development tooling..."

$luaPackages = @(
    @{ Id = 'DEVCOM.Lua';                Name = 'Lua' }
    @{ Id = 'DEVCOM.LuaJIT';             Name = 'LuaJIT' }
    @{ Id = 'LuaLS.lua-language-server'; Name = 'Lua Language Server' }
)

foreach ($pkg in $luaPackages) {
    Install-WingetPackage -Id $pkg.Id -Name $pkg.Name
}

Refresh-Path

Install-CargoBinary -Command 'stylua' -Package 'stylua'

Write-Warn "LuaRocks is not available from winget in the current source. Install it manually if project dependencies require it."
