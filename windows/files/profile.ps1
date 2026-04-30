function Invoke-ProfileScript {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock
    )

    try {
        & $ScriptBlock
    } catch {
        # Keep the shell usable even if an optional tool cannot initialize.
    }
}

function Invoke-ProfileEval {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock
    )

    try {
        $output = & $ScriptBlock 2>$null | Out-String
        if (
            -not [string]::IsNullOrWhiteSpace($output) -and
            $output -notmatch '^\s*echo\s+"Failed to write init script:'
        ) {
            Invoke-Expression $output
        }
    } catch {
        # Optional integrations should fail closed.
    }
}

function Test-CodexShell {
    return (
        -not [string]::IsNullOrWhiteSpace($env:CODEX_THREAD_ID) -or
        -not [string]::IsNullOrWhiteSpace($env:CODEX_SANDBOX_NETWORK_DISABLED) -or
        -not [string]::IsNullOrWhiteSpace($env:CODEX_MANAGED_BY_NPM)
    )
}

$IsCodexShell = Test-CodexShell

# oh-my-posh
if (-not $IsCodexShell -and (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    Invoke-ProfileEval { oh-my-posh init pwsh --print --config "$env:USERPROFILE\.config\oh-my-posh.json" }
}

# PSReadLine
if ($Host.Name -eq 'ConsoleHost') {
    Invoke-ProfileScript { Set-PSReadLineOption -PredictionSource HistoryAndPlugin }
    Invoke-ProfileScript { Set-PSReadLineOption -PredictionViewStyle ListView }
    Invoke-ProfileScript { Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete }
    Invoke-ProfileScript { Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward }
    Invoke-ProfileScript { Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward }
}

# Modules
if (Get-Module -ListAvailable posh-git) { Import-Module posh-git }
if (Get-Module -ListAvailable Terminal-Icons) {
    Invoke-ProfileScript { Import-Module Terminal-Icons -ErrorAction Stop }
}
if (Get-Module -ListAvailable PSFzf) {
    Invoke-ProfileScript {
        Import-Module PSFzf
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    }
}

# zoxide
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-ProfileEval { zoxide init powershell }
}

# fnm
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    Invoke-ProfileEval { fnm env --use-on-cd --shell powershell }
}

# Completions
if (Get-Command rustup -ErrorAction SilentlyContinue) {
    Invoke-ProfileEval { rustup completions powershell }
}
if (Get-Command uv -ErrorAction SilentlyContinue) {
    Invoke-ProfileEval { uv generate-shell-completion powershell }
}
if (Get-Command gh -ErrorAction SilentlyContinue) {
    Invoke-ProfileEval { gh completion -s powershell }
}
