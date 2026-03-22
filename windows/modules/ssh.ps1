Write-Step "Configuring SSH and Git..."

# Enable ssh-agent service
$sshAgent = Get-Service ssh-agent -ErrorAction SilentlyContinue
if ($sshAgent) {
    if ($sshAgent.StartType -ne 'Automatic') {
        Set-Service ssh-agent -StartupType Automatic
        Write-Ok "ssh-agent set to Automatic start"
    }
    if ($sshAgent.Status -ne 'Running') {
        Start-Service ssh-agent
        Write-Ok "ssh-agent started"
    } else {
        Write-Skip "ssh-agent already running"
    }
} else {
    Write-Warn "ssh-agent service not found — ensure OpenSSH Client is installed"
}

# Generate SSH key
$sshDir = Join-Path $env:USERPROFILE '.ssh'
if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
}
$sshKey = Join-Path $sshDir 'id_ed25519'
if (-not (Test-Path $sshKey)) {
    ssh-keygen -t ed25519 -C $UserEmail -f $sshKey -N ([string]::Empty)
    Write-Ok "SSH key generated"
    Write-Host ""
    Write-Host "Add this public key to GitHub:" -ForegroundColor Yellow
    Get-Content "$sshKey.pub"
    Write-Host ""
} else {
    Write-Skip "SSH key already exists"
    Get-Content "$sshKey.pub"
}

# Git config
$gitConfig = @(
    @('user.name',                          $GitUserName)
    @('user.email',                         $UserEmail)
    @('core.editor',                        'nvim')
    @('core.pager',                         'delta')
    @('interactive.diffFilter',             'delta --color-only --features=interactive')
    @('delta.navigate',                     'true')
    @('diff.external',                      'difft')
    @('diff.tool',                          'difftastic')
    @('difftool.difftastic.cmd',            'difft "$LOCAL" "$REMOTE"')
    @('difftool.prompt',                    'false')
    @('diff.algorithm',                     'histogram')
    @('merge.conflictstyle',                'zdiff3')
    @('init.defaultBranch',                 'main')
    @('pull.rebase',                        'true')
    @('push.autoSetupRemote',               'true')
)

foreach ($entry in $gitConfig) {
    $current = git config --global $entry[0] 2>$null
    if ($current -ne $entry[1]) {
        git config --global $entry[0] $entry[1]
        Write-Ok "git config $($entry[0]) = $($entry[1])"
    } else {
        Write-Skip "git config $($entry[0]) already set"
    }
}
