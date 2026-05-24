Write-Step "Inspecting Windows Dev Drive configuration..."

function Invoke-DevDriveCommand {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$Required
    )

    $output = & fsutil @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($output) {
        $output | ForEach-Object { Write-Host "   $_" }
    }

    if ($exitCode -ne 0) {
        $message = "fsutil $($Arguments -join ' ') returned exit code $exitCode"
        if ($Required) {
            throw $message
        }
        Write-Warn $message
        return $false
    }

    return $true
}

if ([string]::IsNullOrWhiteSpace($DevDrivePath)) {
    Write-Step "Querying all Dev Drives..."
    Invoke-DevDriveCommand -Arguments @('devdrv', 'query') | Out-Null
    Write-Skip "Pass -DevDrivePath D: to query or trust a specific Dev Drive"
    return
}

Write-Step "Querying Dev Drive: $DevDrivePath..."
$queryOk = Invoke-DevDriveCommand -Arguments @('devdrv', 'query', $DevDrivePath)

if (-not $DevDriveTrustEnabled) {
    Write-Skip "Dev Drive trust disabled by default; pass -DevDriveTrustEnabled to trust $DevDrivePath"
    return
}

if (-not $queryOk) {
    throw "Cannot trust Dev Drive because query failed for $DevDrivePath"
}

Write-Step "Trusting Dev Drive: $DevDrivePath..."
Invoke-DevDriveCommand -Arguments @('devdrv', 'trust', $DevDrivePath) -Required | Out-Null
Write-Ok "Dev Drive trusted: $DevDrivePath"
