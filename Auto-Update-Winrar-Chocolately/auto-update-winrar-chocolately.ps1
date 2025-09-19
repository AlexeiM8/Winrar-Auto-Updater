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

# Prepare downloader
$webClient = New-Object System.Net.WebClient

# --- Check if Chocolatey exists ---
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "Chocolatey is already installed."
} else {
    Write-Host "Chocolatey not found. Installing Chocolatey..."
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ($webClient.DownloadString('https://community.chocolatey.org/install.ps1'))

        Write-Host "Chocolatey installed successfully."
    } catch {
        Write-Host "Failed to install Chocolatey. $($_.Exception.Message)"
        
        exit 1
    }
}

# Function to get installed WinRAR version
function Get-CurrentWinRARVersion {
    # Check registry for WinRAR installation
    $regPaths = @(
        "HKLM:\SOFTWARE\WinRAR",
        "HKLM:\SOFTWARE\WOW6432Node\WinRAR",
        "HKCU:\SOFTWARE\WinRAR"
    )
    
    foreach ($path in $regPaths) {
        if (Test-Path $path) {
            $version = Get-ItemProperty -Path $path -Name "exe64" -ErrorAction SilentlyContinue
            if ($version) {
                $exePath = $version.exe64
                if (Test-Path $exePath) {
                    $fileVersion = (Get-ItemProperty $exePath).VersionInfo.FileVersion
                    if ($fileVersion) {
                        return $fileVersion
                    }
                }
            }
        }
    }
    
    # Alternative: Check Program Files
    $winrarPaths = @(
        "${env:ProgramFiles}\WinRAR\WinRAR.exe",
        "${env:ProgramFiles(x86)}\WinRAR\WinRAR.exe"
    )
    
    foreach ($path in $winrarPaths) {
        if (Test-Path $path) {
            $fileVersion = (Get-ItemProperty $path).VersionInfo.FileVersion
            if ($fileVersion) {
                return $fileVersion
            }
        }
    }
    
    return $null
}

# Function to get latest WinRAR version that can be installed by chocolately
function Get-LatestWinRARVersion {
    try {
        # Query Chocolatey for WinRAR package info
        $packageInfo = choco search winrar --exact | Select-String "^winrar\s+([\d\.]+)"

        # Extract version using regex
        if ($packageInfo -match "^winrar\s+([\d\.]+)") {
            $latestVersion = $matches[1]
            return $latestVersion
        } else {
            return $null
        }
    } catch {
        # do something
    }
    
    return $null
}

$logfile = "C:\winrar-auto-update.log"

function Log($message) {
    Write-Host "$message"
    "[$($(Get-Date).ToString("dd/MM/yyyy HH:mm:ss"))] $message" | Out-File $logfile -Append
}

if (-not (Get-Process -Name "WinRAR" -ErrorAction SilentlyContinue)) {
    Log "WinRAR is not running. Proceeding with update..."

    $currentVersion = Get-CurrentWinRARVersion

    try {
        # --- Update WinRAR ---
        # Chocolatey cannot detect WinRAR if it's installed manually from rarlab.com, 
        # because it only tracks packages installed through its own system. 
        # To verify whether WinRAR is present on the system in such cases, 
        # we need to use a custom function Get-CurrentWinRARVersion, 
        # which checks registry entries or the actual installation path instead of relying on Chocolatey's package list.
        if($currentVersion) {
            
            $latestVersion = Get-LatestWinRARVersion
            
            if($latestVersion) {
                if([version]$latestVersion -gt [version]$currentVersion) {
                    Log "Starting update..."

                    choco upgrade winrar -y --install-arguments='/S /LANG=English'
            
                    Log "Finished update to version $latestVersion."
                } else {
                    Log "WinRAR is already up to date (version $currentVersion)"
                }
             } else {
                Log "Choco could not retrieve latest version of WinRAR"
             }
        } else {
            Log "WinRAR is not installed. Skipping update."
        }
    } catch {
        Log "ERROR: $($_.Exception.Message)"
    }
} else {
    Log "WinRAR is currently running. Skipping update."
}