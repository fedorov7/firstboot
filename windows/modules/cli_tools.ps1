Write-Step "Installing CLI tools..."

$cliPackages = @(
    @{ Id = 'dandavison.delta';       Name = 'delta' }
    @{ Id = 'sharkdp.hyperfine';      Name = 'hyperfine' }
    @{ Id = 'Casey.Just';             Name = 'just' }
    @{ Id = 'XAMPPRocky.Tokei';       Name = 'tokei' }
    @{ Id = 'JesseDuffield.lazygit';  Name = 'lazygit' }
    @{ Id = 'bootandy.dust';          Name = 'dust' }
    @{ Id = 'Wilfred.difftastic';     Name = 'difftastic' }
)

foreach ($pkg in $cliPackages) {
    Install-WingetPackage -Id $pkg.Id -Name $pkg.Name
}

Install-CargoBinary -Command 'watchexec' -Package 'watchexec-cli' -InstallArgs @('--locked')
