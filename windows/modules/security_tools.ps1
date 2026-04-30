Write-Step "Installing local security and compliance tooling..."

$securityPackages = @(
    @{ Id = 'Gitleaks.Gitleaks';   Name = 'gitleaks' }
    @{ Id = 'AquaSecurity.Trivy';  Name = 'trivy' }
    @{ Id = 'Google.OSVScanner';   Name = 'osv-scanner' }
)

foreach ($pkg in $securityPackages) {
    Install-WingetPackage -Id $pkg.Id -Name $pkg.Name
}

Install-CargoBinary -Command 'cargo-audit' -Package 'cargo-audit'
Install-CargoBinary -Command 'cargo-deny' -Package 'cargo-deny'

Install-UvTool -Command 'flawfinder' -Package 'flawfinder'
Install-UvTool -Command 'codespell' -Package 'codespell'
Install-UvTool -Command 'reuse' -Package 'reuse'
