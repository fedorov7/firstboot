Write-Step "Installing CLI tools..."

$cliPackages = @(
    @{ Id = 'dandavison.delta';       Name = 'delta' }
    @{ Id = 'sharkdp.hyperfine';      Name = 'hyperfine' }
    @{ Id = 'Casey.Just';             Name = 'just' }
    @{ Id = 'Watchexec.Watchexec';    Name = 'watchexec' }
    @{ Id = 'XAMPPRocky.tokei';       Name = 'tokei' }
    @{ Id = 'JesseDuffield.lazygit';  Name = 'lazygit' }
    @{ Id = 'bootandy.dust';          Name = 'dust' }
    @{ Id = 'Wilfred.difftastic';     Name = 'difftastic' }
)

foreach ($pkg in $cliPackages) {
    Install-WingetPackage -Id $pkg.Id -Name $pkg.Name
}
