Write-Step "Installing base packages..."

$basePackages = @(
    @{ Id = 'BurntSushi.ripgrep.MSVC'; Name = 'ripgrep' }
    @{ Id = 'sharkdp.fd';              Name = 'fd' }
    @{ Id = 'sharkdp.bat';             Name = 'bat' }
    @{ Id = 'junegunn.fzf';            Name = 'fzf' }
    @{ Id = 'jqlang.jq';               Name = 'jq' }
    @{ Id = 'MikeFarah.yq';            Name = 'yq' }
    @{ Id = 'eza-community.eza';        Name = 'eza' }
    @{ Id = 'muesli.duf';              Name = 'duf' }
    @{ Id = '7zip.7zip';               Name = '7-Zip' }
    @{ Id = 'voidtools.Everything';     Name = 'Everything' }
    @{ Id = 'Microsoft.PowerToys';      Name = 'PowerToys' }
    @{ Id = 'Git.Git';                 Name = 'Git for Windows' }
    @{ Id = 'GitHub.cli';              Name = 'GitHub CLI' }
)

foreach ($pkg in $basePackages) {
    Install-WingetPackage -Id $pkg.Id -Name $pkg.Name
}
