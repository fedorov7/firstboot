Write-Step "Configuring Windows developer settings..."

function Set-RegistryDword {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$Value,
        [string]$Label = ''
    )

    if ([string]::IsNullOrWhiteSpace($Label)) {
        $Label = "$Path $Name"
    }

    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    $current = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
    if ($current -eq $Value) {
        Write-Skip "$Label already set"
        return
    }

    New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
    Write-Ok "$Label set to $Value"
}

# Avoid path-length failures in deep source trees and package caches.
Set-RegistryDword `
    -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' `
    -Name 'LongPathsEnabled' `
    -Value 1 `
    -Label 'Windows long paths'

# Developer-friendly Explorer defaults. Do not show protected OS files.
$explorerAdvancedPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-RegistryDword -Path $explorerAdvancedPath -Name 'HideFileExt' -Value 0 -Label 'Explorer show file extensions'
Set-RegistryDword -Path $explorerAdvancedPath -Name 'Hidden' -Value 1 -Label 'Explorer show hidden files'
Set-RegistryDword -Path $explorerAdvancedPath -Name 'ShowSuperHidden' -Value 0 -Label 'Explorer hide protected OS files'

if ($WindowsDeveloperModeEnabled) {
    $appModelUnlockPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
    Set-RegistryDword -Path $appModelUnlockPath -Name 'AllowAllTrustedApps' -Value 1 -Label 'Windows sideload trusted apps'
    Set-RegistryDword -Path $appModelUnlockPath -Name 'AllowDevelopmentWithoutDevLicense' -Value 1 -Label 'Windows Developer Mode'
} else {
    Write-Skip "Windows Developer Mode disabled by default; pass -WindowsDeveloperModeEnabled to enable it"
}

Write-Warn "Explorer setting changes may require restarting Explorer or signing out and back in."
