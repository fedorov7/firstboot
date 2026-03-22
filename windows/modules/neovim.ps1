Write-Step "Setting up Neovim..."

Install-WingetPackage -Id 'Neovim.Neovim' -Name 'Neovim'

$nvimConfig = Join-Path $env:LOCALAPPDATA 'nvim'
if (-not (Test-Path $nvimConfig)) {
    Write-Step "Cloning AstroNvim config..."
    git clone $AstroNvimRepo $nvimConfig
    Write-Ok "AstroNvim config cloned to $nvimConfig"
} elseif (Test-Path (Join-Path $nvimConfig '.git')) {
    Write-Step "Updating AstroNvim config..."
    git -C $nvimConfig pull --ff-only
    Write-Ok "AstroNvim config updated"
} else {
    Write-Warn "$nvimConfig exists but is not a git repo — skipping"
}
