param(
    [switch]$register
)

$scriptPath = $MyInvocation.MyCommand.Definition

if ($register) {
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs -register; exit }
} else {
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs; exit }
}

# =================
# SCHEDULE NEW TASK
# =================

$time = [datetime]"03:00:00"

if ($register) {
    try {
        Write-Host "Registering scheduled task 'AutoUpdateWinRAR'..."

        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""

        # Trigger 1: daily at specific time
        $triggerTime = New-ScheduledTaskTrigger -Daily -At $time
        $triggerTime.ExecutionTimeLimit = 'PT1H'   # limit runtime to 1 hour
        $triggerTime.StartBoundary = (Get-Date).Date.Add($time.TimeOfDay).ToString("s")

        $now = (Get-Date)

        if ($now -gt (Get-Date).Date.Add($time.TimeOfDay)) {
            Write-Host "Scheduled time already passed, running script for the first time now..."
            Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
        }

        # Combine triggers
        $triggers = @($triggerTime)

        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable

        $principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -RunLevel Highest

        Register-ScheduledTask -TaskName "AutoUpdateWinRAR" `
                                -Action $action `
                                -Trigger $triggers `
                                -Principal $principal `
                                -Settings $settings `
                                -Force `
                                -Description "Daily auto update WinRAR"

        Write-Host "Task registered. It will run daily at $($time.TimeOfDay), or on next login if missed."

        exit
    } catch {
        Write-Host "Failed to scheduled task 'AutoUpdateWinRAR'..."
        Write-Host "$($_.Exception.Message)"

        exit 1
    }
}

# ========================
# MAIN UPDATE LOGIC BELOW
# ========================

# Detect architecture
$systemarch = $env:PROCESSOR_ARCHITECTURE
Write-Host "System architecture detected: $systemarch"

switch ($systemarch) {
    "AMD64" { $arch = "x64" }
    "x86"   { $arch = "x86" }
    "ARM64" { $arch = "arm64" }
    "ARM"   { $arch = "arm" }
    default { $arch = "" }  # fallback
}

# Function to compare version strings
function VersionLess($v1, $v2) {
    return ([Version]$v1).CompareTo([Version]$v2) -lt 0
}

# Function to read app version from an .appx file
function GetVersion($appxPath) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $zip = [System.IO.Compression.ZipFile]::OpenRead($appxPath)

    $manifestEntry = $zip.Entries | Where-Object { $_.FullName -eq "AppxManifest.xml" }
    $reader = New-Object IO.StreamReader($manifestEntry.Open())
    $xml = [xml]$reader.ReadToEnd()
    $reader.Close()
    $zip.Dispose()

    $xml.Package.Identity.Version
}

# Prepare downloader
$webClient = New-Object System.Net.WebClient

# --- Check if winget exists ---
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "Winget is already installed."
} else {
    Write-Host "Winget not found. Installing App Installer (winget)..."

    $dependenciesUrl = "https://github.com/microsoft/winget-cli/releases/latest/download/DesktopAppInstaller_Dependencies.zip"
    $dependenciesZipPath = Join-Path $env:TEMP "DesktopAppInstaller_Dependencies.zip"
    $dependenciesExtractPath = Join-Path $env:TEMP "DesktopAppInstaller_Dependencies"

    try {
        Write-Host "Downloading dependencies zip."

        $webClient.DownloadFile($dependenciesUrl, $dependenciesZipPath)

        Write-Host "Downloaded dependencies zip."
    } catch {
        Write-Host "Failed to download dependencies: $($_.Exception.Message)"
        exit 1
    }

    try {
        if(Test-Path $dependenciesZipPath) {
            Write-Host "Extracting dependencies to $dependenciesExtractPath."

            Expand-Archive -Path $dependenciesZipPath -DestinationPath $dependenciesExtractPath -Force

            Write-Host "Extracted dependencies to $dependenciesExtractPath."
        } else {
            Write-Host "Error: $dependenciesZipPath was not created!"
        }
    } catch {
        Write-Host "Failed to extract dependencies."
        exit 1
    }


    $Microsoft_UI_Xaml_appxPath = Get-ChildItem -Path $dependenciesExtractPath -Recurse -Filter "Microsoft.UI.Xaml.2.8*$arch.appx" -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -like "Microsoft.UI.Xaml.2.8*$arch.appx"
    } | Select-Object -First 1

    $doInstall_Microsoft_UI_Xaml = $false

    $Microsoft_UI_Xaml_Pkg = Get-AppxPackage -Name "Microsoft.UI.Xaml.2.8*" -ErrorAction SilentlyContinue

    if($Microsoft_UI_Xaml_Pkg) {
        $Microsoft_UI_Xaml_Pkg_Version = [Version]$Microsoft_UI_Xaml_Pkg.Version
        if (VersionLess $Microsoft_UI_Xaml_Pkg_Version (GetVersion $Microsoft_UI_Xaml_appxPath.FullName)) {
            $doInstall_Microsoft_UI_Xaml = $true
        }
    } else {
        $doInstall_Microsoft_UI_Xaml = $true
    }

    if($doInstall_Microsoft_UI_Xaml) {
        if ($Microsoft_UI_Xaml_appxPath) {
            try {
                Write-Host "Installing $($Microsoft_UI_Xaml_appxPath.Name)"
                Add-AppxPackage -Path $Microsoft_UI_Xaml_appxPath.FullName
                Write-Host "$($Microsoft_UI_Xaml_appxPath.Name) installed successfully."
            } catch {
                Write-Host "Failed to install Microsoft.UI.Xaml: $($_.Exception.Message)"
                exit 1
            }
        } else {
            Write-Host "Could not find Microsoft.UI.Xaml appx file for $arch architecture"
            exit 1
        }
    }


    $Microsoft_VCLibs_appxPath = Get-ChildItem -Path $dependenciesExtractPath -Recurse -Filter "Microsoft.VCLibs.140.00.UWPDesktop*$arch.appx" -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -like "Microsoft.VCLibs.140.00.UWPDesktop*$arch.appx"
    } | Select-Object -First 1

    $doInstall_Microsoft_VCLibs = $false

    $Microsoft_VCLibs_Pkg = Get-AppxPackage -Name "Microsoft.VCLibs.140.00.UWPDesktop*" -ErrorAction SilentlyContinue

    if($Microsoft_VCLibs_Pkg) {
        $Microsoft_VCLibs_Pkg_Version = [Version]$Microsoft_VCLibs_Pkg.Version
        if (VersionLess $Microsoft_VCLibs_Pkg_Version (GetVersion $Microsoft_VCLibs_appxPath.FullName)) {
            $doInstall_Microsoft_VCLibs = $true
        }
    } else {
        $doInstall_Microsoft_VCLibs = $true
    }

    if($doInstall_Microsoft_VCLibs) {
        if ($Microsoft_VCLibs_appxPath) {
            try {
                Write-Host "Installing $($Microsoft_VCLibs_appxPath.Name)"
                Add-AppxPackage -Path $Microsoft_VCLibs_appxPath.FullName
                Write-Host "$($Microsoft_VCLibs_appxPath.Name) installed successfully."
            } catch {
                Write-Host "Failed to install Microsoft.VCLibs: $($_.Exception.Message)"
                exit 1
            }
        } else {
            Write-Host "Could not find Microsoft.VCLibs appx file for $arch architecture."
            exit 1
        }
    }


    $wingetUrl = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    $wingetTmpPath = Join-Path $env:TEMP "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"


    try {
        Write-Host "Downloading winget bundle."

        $webClient.DownloadFile($wingetUrl, $wingetTmpPath)

        Write-Host "Downloaded winget bundle."
    } catch {
        Write-Host "Failed to download winget bundle: $($_.Exception.Message)"
        exit 1
    }

    try {
        if(Test-Path $wingetTmpPath) {
            $wingetTmpPath = Get-Item $wingetTmpPath

            Write-Host "Installing $($wingetTmpPath.Name)"

            Add-AppxPackage -Path $wingetTmpPath.FullName

            Write-Host "$($wingetTmpPath.Name) installed successfully."
        }
    } catch {
        Write-Host "Failed to install winget. $($_.Exception.Message)"
        exit 1
    }

    # Clean up
    Write-Host "Start cleaning up."
    if (Test-Path $dependenciesZipPath) { Remove-Item $dependenciesZipPath -Recurse -Force }
    if (Test-Path $dependenciesExtractPath) { Remove-Item $dependenciesExtractPath -Recurse -Force }
    if (Test-Path $wingetTmpPath)    { Remove-Item $wingetTmpPath -Recurse -Force }
    Write-Host " Completed Cleaning up."
}

function Test-WinRARInstalled {
    $result = winget list --id RARLab.WinRAR 2>$null
    if ($LASTEXITCODE -eq 0 -and $result -match "WinRAR") {
        return $true
    } else {
        return $false
    }
}

$logfile = "C:\winrar-auto-update.log"

function Log($message) {
    Write-Host "$message"
    "[$($(Get-Date).ToString("dd/MM/yyyy HH:mm:ss"))] $message" | Out-File $logfile -Append
}

if (-not (Get-Process -Name "WinRAR" -ErrorAction SilentlyContinue)) {
    Log "WinRAR is not running. Proceeding with update..."

    try {
        # --- Update WinRAR ---
        if(Test-WinRARInstalled) {
            Log "Starting update..."

            winget update --id RARLab.WinRAR --exact --silent --override '/S /LANG=English' --accept-package-agreements --accept-source-agreements
            
            Log "Finished update."
        } else {
            Log "WinRAR is not installed. Skipping update."

            # winget install --id RARLab.WinRAR --exact --silent --override '/S /LANG=English' --accept-package-agreements --accept-source-agreements
        }
    } catch {
        Log "ERROR: $($_.Exception.Message)"
    }
} else {
    Log "WinRAR is currently running. Skipping update."
}