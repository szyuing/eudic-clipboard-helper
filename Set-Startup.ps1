param(
    [switch]$Disable
)

$ErrorActionPreference = "Stop"

function Get-AhkExe {
    $candidates = @(
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey.exe",
        "$env:ProgramFiles\AutoHotkey\AutoHotkey64.exe",
        "$env:ProgramFiles\AutoHotkey\AutoHotkey.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    foreach ($command in @("AutoHotkey64.exe", "AutoHotkey.exe")) {
        $resolved = Get-Command $command -ErrorAction SilentlyContinue
        if ($resolved) {
            return $resolved.Source
        }
    }

    return $null
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$helperPath = Join-Path $scriptDir "EudicClipboardHelper.ahk"
$startupFolder = [Environment]::GetFolderPath("Startup")
$shortcutPath = Join-Path $startupFolder "Eudic Clipboard Helper.lnk"

if ($Disable) {
    if (Test-Path $shortcutPath) {
        Remove-Item $shortcutPath -Force
        Write-Host "Startup disabled."
        Write-Host "Removed: $shortcutPath"
    } else {
        Write-Host "Startup shortcut was not present."
    }
    exit 0
}

if (-not (Test-Path $helperPath)) {
    throw "Helper script not found: $helperPath"
}

$ahkExe = Get-AhkExe
if (-not $ahkExe) {
    throw "AutoHotkey v2 was not found. Install it first, then run this script again."
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $ahkExe
$shortcut.Arguments = '"' + $helperPath + '"'
$shortcut.WorkingDirectory = $scriptDir
$shortcut.WindowStyle = 7
$shortcut.Description = "Start Eudic Clipboard Helper at login"
$shortcut.Save()

Write-Host "Startup enabled."
Write-Host "Shortcut: $shortcutPath"
