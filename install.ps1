$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "[EudicClipboardHelper] $Message"
}

function Test-Windows {
    if (-not $IsWindows) {
        throw "This installer only supports Windows."
    }
}

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

    $commands = @("AutoHotkey64.exe", "AutoHotkey.exe")
    foreach ($command in $commands) {
        $resolved = Get-Command $command -ErrorAction SilentlyContinue
        if ($resolved) {
            return $resolved.Source
        }
    }

    return $null
}

function Test-EudicRegistered {
    return Test-Path "Registry::HKEY_CLASSES_ROOT\eudic"
}

function Ensure-Winget {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw "winget was not found. Install App Installer from Microsoft Store first."
    }
}

function Install-AutoHotkey {
    if (Get-AhkExe) {
        Write-Step "AutoHotkey v2 already found."
        return
    }

    Ensure-Winget
    Write-Step "Installing AutoHotkey v2..."
    & winget install --id AutoHotkey.AutoHotkey --exact --accept-package-agreements --accept-source-agreements

    $ahkExe = Get-AhkExe
    if (-not $ahkExe) {
        throw "AutoHotkey v2 installation finished but executable was not found."
    }
}

function Install-Eudic {
    if (Test-EudicRegistered) {
        Write-Step "Eudic protocol already registered."
        return
    }

    Ensure-Winget
    Write-Step "Installing Eudic..."
    & winget install --id EuSoft.Eudic --exact --accept-package-agreements --accept-source-agreements

    for ($i = 0; $i -lt 24; $i++) {
        Start-Sleep -Seconds 5
        if (Test-EudicRegistered) {
            return
        }
    }

    throw "Eudic installation did not register the eudic:// protocol in time."
}

function Download-ProjectFiles {
    param(
        [string]$InstallDir
    )

    $baseUrl = "https://raw.githubusercontent.com/szyuing/eudic-clipboard-helper/main"
    $files = @(
        "EudicClipboardHelper.ahk",
        "run.bat",
        "README.md",
        "remand.md"
    )

    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

    foreach ($file in $files) {
        $destination = Join-Path $InstallDir $file
        $url = "$baseUrl/$file"
        Write-Step "Downloading $file..."
        Invoke-WebRequest -Uri $url -OutFile $destination
    }
}

function Set-StartupShortcut {
    param(
        [string]$AhkExe,
        [string]$InstallDir
    )

    $startupFolder = [Environment]::GetFolderPath("Startup")
    $shortcutPath = Join-Path $startupFolder "Eudic Clipboard Helper.lnk"
    $scriptPath = Join-Path $InstallDir "EudicClipboardHelper.ahk"

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $AhkExe
    $shortcut.Arguments = '"' + $scriptPath + '"'
    $shortcut.WorkingDirectory = $InstallDir
    $shortcut.WindowStyle = 7
    $shortcut.Description = "Start Eudic Clipboard Helper at login"
    $shortcut.Save()
}

function Start-Helper {
    param(
        [string]$AhkExe,
        [string]$InstallDir
    )

    $scriptPath = Join-Path $InstallDir "EudicClipboardHelper.ahk"
    Start-Process -FilePath $AhkExe -ArgumentList ('"' + $scriptPath + '"') -WorkingDirectory $InstallDir
}

Test-Windows

$installDir = Join-Path $env:LOCALAPPDATA "EudicClipboardHelper"

Write-Step "Checking dependencies..."
Install-AutoHotkey
Install-Eudic

$ahkExe = Get-AhkExe
if (-not $ahkExe) {
    throw "AutoHotkey v2 is still missing."
}

Write-Step "Preparing local files..."
Download-ProjectFiles -InstallDir $installDir

Write-Step "Configuring startup..."
Set-StartupShortcut -AhkExe $ahkExe -InstallDir $installDir

Write-Step "Starting helper..."
Start-Helper -AhkExe $ahkExe -InstallDir $installDir

Write-Host ""
Write-Host "Install complete."
Write-Host "Install path: $installDir"
Write-Host "Startup: enabled"
Write-Host "You can test it now by copying: apple"
