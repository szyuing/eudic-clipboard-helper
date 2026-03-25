$ErrorActionPreference = "Stop"

$RepoOwner = "szyuing"
$RepoName = "eudic-clipboard-helper"
$DownloadBaseUrls = @(
    "https://raw.githubusercontent.com/$RepoOwner/$RepoName/main",
    "https://github.com/$RepoOwner/$RepoName/raw/main"
)
$DownloadableFiles = @(
    "EudicClipboardHelper.ahk",
    "run.bat",
    "Set-Startup.ps1",
    "README.md",
    "remand.md"
)

function Write-Step {
    param([string]$Message)

    Write-Host "[EudicClipboardHelper] $Message"
}

function Test-Windows {
    $isWindows = $false

    if (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue) {
        $isWindows = [bool]$IsWindows
    } elseif ($env:OS -eq "Windows_NT") {
        $isWindows = $true
    }

    if (-not $isWindows) {
        throw "This installer only supports Windows."
    }
}

function Initialize-NetworkDefaults {
    try {
        $tls12 = [Net.SecurityProtocolType]::Tls12
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor $tls12
    } catch {
        Write-Step "Could not adjust TLS defaults. Continuing with current settings."
    }
}

function Test-AhkV2Executable {
    param([string]$Path)

    if (-not $Path -or -not (Test-Path $Path)) {
        return $false
    }

    try {
        $item = Get-Item $Path
        if ($item.VersionInfo.FileMajorPart -ge 2) {
            return $true
        }
    } catch {
        # Fall through to path heuristics below.
    }

    return $Path -match '[\\/]v2[\\/]'
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
        if (Test-AhkV2Executable $candidate) {
            return $candidate
        }
    }

    $commands = @("AutoHotkey64.exe", "AutoHotkey.exe")
    foreach ($command in $commands) {
        $resolved = Get-Command $command -ErrorAction SilentlyContinue
        if ($resolved -and (Test-AhkV2Executable $resolved.Source)) {
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

    return $winget.Source
}

function Invoke-ExternalCommand {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$FailureMessage
    )

    & $FilePath @Arguments
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "$FailureMessage Exit code: $exitCode"
    }
}

function Wait-ForCondition {
    param(
        [scriptblock]$Condition,
        [int]$TimeoutSeconds = 120,
        [int]$PollSeconds = 5
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if (& $Condition) {
            return $true
        }

        Start-Sleep -Seconds $PollSeconds
    } while ((Get-Date) -lt $deadline)

    return $false
}

function Install-AutoHotkey {
    $ahkExe = Get-AhkExe
    if ($ahkExe) {
        Write-Step "AutoHotkey v2 already found at $ahkExe"
        return $ahkExe
    }

    $winget = Ensure-Winget
    Write-Step "Installing AutoHotkey v2 with winget..."
    Invoke-ExternalCommand -FilePath $winget -Arguments @(
        "install",
        "--id", "AutoHotkey.AutoHotkey",
        "--exact",
        "--accept-package-agreements",
        "--accept-source-agreements"
    ) -FailureMessage "AutoHotkey v2 installation failed."

    if (-not (Wait-ForCondition -Condition { Get-AhkExe } -TimeoutSeconds 60 -PollSeconds 3)) {
        throw "AutoHotkey v2 installation finished, but no v2 executable was found. Try reinstalling AutoHotkey manually from https://www.autohotkey.com/ ."
    }

    return (Get-AhkExe)
}

function Install-Eudic {
    if (Test-EudicRegistered) {
        Write-Step "Eudic protocol already registered."
        return
    }

    $winget = Ensure-Winget
    Write-Step "Installing Eudic with winget..."
    Invoke-ExternalCommand -FilePath $winget -Arguments @(
        "install",
        "--id", "EuSoft.Eudic",
        "--exact",
        "--accept-package-agreements",
        "--accept-source-agreements"
    ) -FailureMessage "Eudic installation failed."

    if (-not (Wait-ForCondition -Condition { Test-EudicRegistered } -TimeoutSeconds 120 -PollSeconds 5)) {
        throw "Eudic installed, but the eudic:// protocol was not registered in time. Open Eudic once manually, then test Win+R -> eudic://lp-dict/test ."
    }
}

function Get-CurlExe {
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curl) {
        return $curl.Source
    }

    return $null
}

function Invoke-DownloadWithIwr {
    param(
        [string]$Url,
        [string]$Destination
    )

    Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
}

function Invoke-DownloadWithCurl {
    param(
        [string]$Url,
        [string]$Destination
    )

    $curlExe = Get-CurlExe
    if (-not $curlExe) {
        throw "curl.exe was not found."
    }

    Invoke-ExternalCommand -FilePath $curlExe -Arguments @(
        "--fail",
        "--location",
        "--silent",
        "--show-error",
        "--output", $Destination,
        $Url
    ) -FailureMessage "curl.exe download failed."
}

function Download-File {
    param(
        [string]$RelativePath,
        [string]$Destination
    )

    $attemptErrors = New-Object System.Collections.Generic.List[string]
    $destinationDir = Split-Path -Path $Destination -Parent
    New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null

    foreach ($baseUrl in $DownloadBaseUrls) {
        $url = "$baseUrl/$RelativePath"

        foreach ($downloader in @("Invoke-WebRequest", "curl.exe")) {
            for ($attempt = 1; $attempt -le 2; $attempt++) {
                $tempFile = "$Destination.download"
                if (Test-Path $tempFile) {
                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                }

                try {
                    if ($downloader -eq "Invoke-WebRequest") {
                        Invoke-DownloadWithIwr -Url $url -Destination $tempFile
                    } else {
                        Invoke-DownloadWithCurl -Url $url -Destination $tempFile
                    }

                    if (-not (Test-Path $tempFile) -or ((Get-Item $tempFile).Length -le 0)) {
                        throw "Downloaded file was empty."
                    }

                    Move-Item -Force -Path $tempFile -Destination $Destination
                    return
                } catch {
                    $attemptErrors.Add("$downloader attempt $attempt failed for $url : $($_.Exception.Message)")
                    Start-Sleep -Seconds 2
                } finally {
                    if (Test-Path $tempFile) {
                        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    }

    $details = $attemptErrors -join [Environment]::NewLine
    throw "Failed to download $RelativePath from GitHub.`n$details"
}

function Download-ProjectFiles {
    param([string]$InstallDir)

    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

    foreach ($file in $DownloadableFiles) {
        $destination = Join-Path $InstallDir $file
        Write-Step "Downloading $file..."
        Download-File -RelativePath $file -Destination $destination
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

function Test-HelperRunning {
    param([string]$ScriptPath)

    $escapedScriptPath = [Regex]::Escape($ScriptPath)
    $processes = Get-CimInstance Win32_Process -Filter "Name = 'AutoHotkey.exe' OR Name = 'AutoHotkey64.exe'" -ErrorAction SilentlyContinue
    if (-not $processes) {
        return $false
    }

    foreach ($process in $processes) {
        if ($process.CommandLine -match $escapedScriptPath) {
            return $true
        }
    }

    return $false
}

function Start-Helper {
    param(
        [string]$AhkExe,
        [string]$InstallDir
    )

    $scriptPath = Join-Path $InstallDir "EudicClipboardHelper.ahk"

    if (Test-HelperRunning -ScriptPath $scriptPath) {
        Write-Step "Helper is already running."
        return
    }

    Start-Process -FilePath $AhkExe -ArgumentList ('"' + $scriptPath + '"') -WorkingDirectory $InstallDir
}

Test-Windows
Initialize-NetworkDefaults

$installDir = Join-Path $env:LOCALAPPDATA "EudicClipboardHelper"

Write-Step "Checking dependencies..."
$ahkExe = Install-AutoHotkey
Install-Eudic

if (-not $ahkExe) {
    $ahkExe = Get-AhkExe
}

if (-not $ahkExe) {
    throw "AutoHotkey v2 is still missing after installation. Install it manually from https://www.autohotkey.com/ and run this installer again."
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
