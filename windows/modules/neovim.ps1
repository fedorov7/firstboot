Write-Step "Setting up Neovim..."

Install-WingetPackage -Id 'Neovim.Neovim' -Name 'Neovim'

$nvimConfig = Join-Path $env:LOCALAPPDATA 'nvim'
$nvimCleanupPaths = @(
    $nvimConfig
    (Join-Path $env:LOCALAPPDATA 'nvim-data')
    (Join-Path $env:LOCALAPPDATA 'nvim-state')
    (Join-Path $env:TEMP 'nvim')
)
$nvimConfigGit = Join-Path $nvimConfig '.git'
$shouldCleanup = $ForceNeovimCleanup -or ((Test-Path $nvimConfig) -and -not (Test-Path $nvimConfigGit))

if ($shouldCleanup) {
    foreach ($path in $nvimCleanupPaths) {
        if (Test-Path $path) {
            Remove-Item -LiteralPath $path -Recurse -Force
            Write-Ok "Removed stale Neovim path: $path"
        }
    }
}

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
