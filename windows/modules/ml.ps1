Write-Step "Setting up Windows ML Python environment..."

if (-not (Test-CommandExists uv)) {
    Write-Warn "uv not available. Run python module first to install ML packages."
    return
}

if ([string]::IsNullOrWhiteSpace($MlEnvironmentPath)) {
    $MlEnvironmentPath = Join-Path $env:USERPROFILE '.virtualenvs\firstboot-ml'
}

$mlPackages = ConvertTo-NameList $MlPythonPackages
if ($mlPackages.Count -eq 0) {
    Write-Warn "MlPythonPackages is empty; skipping ML package installation."
    return
}

uv python install $MlPythonVersion
if ($LASTEXITCODE -ne 0) {
    throw "uv python install $MlPythonVersion returned exit code $LASTEXITCODE"
}

if (-not (Test-Path (Join-Path $MlEnvironmentPath 'pyvenv.cfg'))) {
    Write-Step "Creating ML virtual environment at $MlEnvironmentPath..."
    uv venv --python $MlPythonVersion $MlEnvironmentPath
    if ($LASTEXITCODE -ne 0) {
        throw "uv venv returned exit code $LASTEXITCODE"
    }
    Write-Ok "ML virtual environment created"
} else {
    Write-Skip "ML virtual environment already exists"
}

$mlPython = Join-Path $MlEnvironmentPath 'Scripts\python.exe'
if (-not (Test-Path $mlPython)) {
    throw "ML Python executable not found: $mlPython"
}

Write-Step "Installing ML packages into $MlEnvironmentPath..."
uv pip install --python $mlPython @mlPackages
if ($LASTEXITCODE -ne 0) {
    throw "uv pip install ML packages returned exit code $LASTEXITCODE"
}
Write-Ok "ML Python packages installed"

& $mlPython -m ipykernel install --user --name firstboot-ml --display-name "Python (firstboot-ml)"
if ($LASTEXITCODE -ne 0) {
    throw "ipykernel install returned exit code $LASTEXITCODE"
}
Write-Ok "Jupyter kernel registered: Python (firstboot-ml)"
