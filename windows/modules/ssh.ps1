Write-Step "Configuring SSH and Git..."

function Get-FirstbootGitConfigEntries {
    param(
        [Parameter(Mandatory)][string]$GitUserName,
        [Parameter(Mandatory)][string]$UserEmail
    )

    @(
        [pscustomobject]@{ Key = 'user.name';               Value = $GitUserName }
        [pscustomobject]@{ Key = 'user.email';              Value = $UserEmail }
        [pscustomobject]@{ Key = 'core.editor';             Value = 'nvim' }
        [pscustomobject]@{ Key = 'core.pager';              Value = 'delta' }
        [pscustomobject]@{ Key = 'interactive.diffFilter';  Value = 'delta --color-only --features=interactive' }
        [pscustomobject]@{ Key = 'delta.navigate';          Value = 'true' }
        [pscustomobject]@{ Key = 'diff.external';           Value = 'difft' }
        [pscustomobject]@{ Key = 'diff.tool';               Value = 'difftastic' }
        [pscustomobject]@{ Key = 'difftool.difftastic.cmd'; Value = 'difft "$LOCAL" "$REMOTE"' }
        [pscustomobject]@{ Key = 'difftool.prompt';         Value = 'false' }
        [pscustomobject]@{ Key = 'pager.difftool';          Value = 'true' }
        [pscustomobject]@{ Key = 'diff.algorithm';          Value = 'histogram' }
        [pscustomobject]@{ Key = 'merge.conflictstyle';     Value = 'zdiff3' }
        [pscustomobject]@{ Key = 'init.defaultBranch';      Value = 'main' }
        [pscustomobject]@{ Key = 'fetch.prune';             Value = 'true' }
        [pscustomobject]@{ Key = 'pull.rebase';             Value = 'true' }
        [pscustomobject]@{ Key = 'rebase.autoStash';        Value = 'true' }
        [pscustomobject]@{ Key = 'push.autoSetupRemote';    Value = 'true' }
        [pscustomobject]@{ Key = 'rerere.enabled';          Value = 'true' }
        [pscustomobject]@{ Key = 'alias.dft';               Value = '-c diff.external=difft diff' }
        [pscustomobject]@{ Key = 'alias.ds';                Value = '-c diff.external=difft show --ext-diff' }
        [pscustomobject]@{ Key = 'alias.dl';                Value = '-c diff.external=difft log -p --ext-diff' }
    )
}

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
$gitConfig = @(Get-FirstbootGitConfigEntries -GitUserName $GitUserName -UserEmail $UserEmail)

foreach ($entry in $gitConfig) {
    $current = git config --global $entry.Key 2>$null
    if ($current -ne $entry.Value) {
        git config --global $entry.Key $entry.Value
        if ($LASTEXITCODE -ne 0) {
            throw "git config --global $($entry.Key) failed with exit code $LASTEXITCODE"
        }
        Write-Ok "git config $($entry.Key) = $($entry.Value)"
    } else {
        Write-Skip "git config $($entry.Key) already set"
    }
}
