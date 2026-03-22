Write-Step "Setting up Rust..."

Install-WingetPackage -Id 'Rustlang.Rustup' -Name 'rustup'

Refresh-Path

if (Test-CommandExists rustup) {
    # Set stable as default
    $default = rustup default 2>&1
    if ($default -notmatch 'stable') {
        rustup default stable
        Write-Ok "Rust stable set as default"
    } else {
        Write-Skip "Rust stable already default"
    }

    # Install components
    $installed = rustup component list --installed 2>&1
    $components = @('rust-analyzer', 'clippy', 'rustfmt')
    foreach ($comp in $components) {
        if ($installed -notmatch $comp) {
            rustup component add $comp
            Write-Ok "Component $comp installed"
        } else {
            Write-Skip "Component $comp already installed"
        }
    }

    # Install sccache
    if (-not (Test-CommandExists sccache)) {
        Write-Step "Installing sccache..."
        cargo install sccache
        Write-Ok "sccache installed"
    } else {
        Write-Skip "sccache already installed"
    }
} else {
    Write-Warn "rustup not found in PATH after install — restart shell and re-run"
}
