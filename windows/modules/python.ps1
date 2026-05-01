Write-Step "Setting up Python via uv..."

Install-WingetPackage -Id 'astral-sh.uv' -Name 'uv'
Install-WingetPackage -Id 'astral-sh.ruff' -Name 'ruff'

Refresh-Path

if (Test-CommandExists uv) {
    # Install Python 3.12
    $pyVersions = uv python list --installed 2>&1
    if ($pyVersions -notmatch '3\.12') {
        Write-Step "Installing Python 3.12 via uv..."
        uv python install 3.12
        Write-Ok "Python 3.12 installed"
    } else {
        Write-Skip "Python 3.12 already installed"
    }

    # Install global tools
    $uvTools = @('pyright', 'mypy', 'black', 'pytest', 'pre-commit', 'tox', 'nox', 'ipython')
    foreach ($tool in $uvTools) {
        if (-not (Test-CommandExists $tool)) {
            Write-Step "Installing $tool via uv tool..."
            uv tool install $tool
            Write-Ok "$tool installed"
        } else {
            Write-Skip "$tool already available"
        }
    }
} else {
    Write-Warn "uv not found in PATH after install — restart shell and re-run"
}
