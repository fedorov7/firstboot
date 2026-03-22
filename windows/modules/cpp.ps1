Write-Step "Setting up C++ toolchain..."

# Check VS Build Tools
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) {
    $vsInstalls = & $vswhere -products * -requires Microsoft.VisualStudio.Workload.VCTools -format json | ConvertFrom-Json
    if ($vsInstalls.Count -gt 0) {
        Write-Ok "VS Build Tools found: $($vsInstalls[0].installationPath)"
    } else {
        Write-Warn "VS Build Tools installed but C++ workload not found. Install 'Desktop development with C++' workload."
    }
} else {
    Write-Warn "Visual Studio Installer not found — VS Build Tools may not be installed"
}

# Build system tools
Install-WingetPackage -Id 'Kitware.CMake' -Name 'CMake'
Install-WingetPackage -Id 'Ninja-build.Ninja' -Name 'Ninja'
Install-WingetPackage -Id 'LLVM.LLVM' -Name 'LLVM (clang, clangd, clang-format)'
Install-WingetPackage -Id 'mesonbuild.meson' -Name 'Meson'

# Debugging tools
Install-WingetPackage -Id 'Microsoft.WinDbg' -Name 'WinDbg'
Install-WingetPackage -Id 'Microsoft.Sysinternals.Suite' -Name 'Sysinternals Suite'

# vcpkg
$vcpkgRoot = Join-Path $env:USERPROFILE 'vcpkg'
if (-not (Test-Path (Join-Path $vcpkgRoot '.git'))) {
    Write-Step "Cloning vcpkg..."
    git clone https://github.com/microsoft/vcpkg.git $vcpkgRoot
    & (Join-Path $vcpkgRoot 'bootstrap-vcpkg.bat') -disableMetrics
    Write-Ok "vcpkg cloned and bootstrapped at $vcpkgRoot"
} else {
    Write-Step "Updating vcpkg..."
    git -C $vcpkgRoot pull --ff-only
    Write-Ok "vcpkg updated"
}

# Set VCPKG_ROOT if not set
if (-not $env:VCPKG_ROOT) {
    [System.Environment]::SetEnvironmentVariable('VCPKG_ROOT', $vcpkgRoot, 'User')
    $env:VCPKG_ROOT = $vcpkgRoot
    Write-Ok "VCPKG_ROOT set to $vcpkgRoot"
}
