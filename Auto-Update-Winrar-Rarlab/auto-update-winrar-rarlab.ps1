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
        Write-Host "Registering scheduled task 'AutoUpdateWinRAR_DarkMethod'..."

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

        Register-ScheduledTask -TaskName "AutoUpdateWinRAR_DarkMethod" `
                                -Action $action `
                                -Trigger $triggers `
                                -Principal $principal `
                                -Settings $settings `
                                -Force `
                                -Description "Daily auto update WinRAR"

        Write-Host "Task registered. It will run daily at $($time.TimeOfDay), or on next login if missed."

        exit
    } catch {
        Write-Host "Failed to scheduled task 'AutoUpdateWinRAR_DarkMethod'..."
        Write-Host "$($_.Exception.Message)"

        exit 1
    }
}


# ========================
# MAIN UPDATE LOGIC BELOW
# ========================

$webClient = New-Object System.Net.WebClient
$webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")

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

# Function to get latest WinRAR version from rarlab.com
function Get-LatestWinRARVersion {
    try {       
        # Get the download page
        $downloadPage = $webClient.DownloadString("https://www.rarlab.com/download.htm")
        
        # Look for beta versions first
        # Pattern: "WinRAR x.xx beta x" or "WinRAR x.xx beta"

        $betaPattern = 'WinRAR.+(\d+\.\d+)\s+beta\s*(\d*)'
        if ($downloadPage -match $betaPattern) {
            $baseVersion = $matches[1]
            $betaNumber = if ($matches[2]) { $matches[2] } else { "1" }
            Write-Host "Found beta version: WinRAR $baseVersion beta $betaNumber"
            return @{
                Version = "$baseVersion.$betaNumber"
                IsBeta = $true
                BaseVersion = $baseVersion
                BetaNumber = $betaNumber
                DisplayName = "WinRAR $baseVersion beta $betaNumber"
            }
        }

        # Look for stable versions
        # Pattern: "WinRAR x.xx"

        $stablePattern = 'WinRAR.+(\d+\.\d+)(?!\s+beta)'
        if ($downloadPage -match $stablePattern) {
            $stableVersion = $matches[1]
            Write-Host "Found stable version: WinRAR $stableVersion.0"
            return @{
                Version = "$stableVersion.0"
                IsBeta = $false
                BaseVersion = $stableVersion
                BetaNumber = $null
                DisplayName = "WinRAR $stableVersion"
            }
        }
        
        # Alternative: Look for direct download links. Can match both beta versions and stable versions
        # Pattern: "winrar.+\d+(?:b\d+)?\.exe"
        # Example: "winrar-x64-620b1.exe", "winrar-x32-700b2.exe", "winrar-x64-713.exe"

        $linkPattern = 'winrar.+\d+(?:b\d+)?\.exe'
        if ($downloadPage -match $linkPattern) {
            $filename = $matches[0]

            # Parse beta files like "winrar-x32-700b2.exe" -> 7.10 beta 2
            if ($filename -match 'winrar.+(\d)(\d+)b(\d+)\.exe') {
                $major = $matches[1]
                $minor = $matches[2]
                $beta = $matches[3]
                Write-Host "Found beta version: WinRAR $major.$minor beta $beta"
                return @{
                    Version = "$major.$minor.$beta"
                    IsBeta = $true
                    BaseVersion = "$major.$minor"
                    BetaNumber = $beta
                    DisplayName = "$major.$minor beta $beta"
                }
            }
            # Parse stable files like "winrar-x64-713.exe" -> 7.13
            elseif ($filename -match 'winrar.+(\d)(\d+)b(\d+)\.exe') {
                $major = $matches[1]
                $minor = $matches[2]
                Write-Host "Found stable version: WinRAR $major.$minor.0"
                return @{
                    Version = "$major.$minor.0"
                    IsBeta = $false
                    BaseVersion = "$major.$minor"
                    BetaNumber = $null
                    DisplayName = "$major.$minor"
                }
            }
        }

        return $null

    } catch {
        Write-Host "Failed to get latest version from rarlab.com: $($_.Exception.Message)"
        return $null
    }
}

# Function to download and install WinRAR
function Download-And-Install($downloadUrl) {

}

# Function to download and install WinRAR
function Install-WinRAR($versionInfo) {
    try {
        # Detect architecture
        $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x32" }

        $filename = $null
        
        # Construct filename based on version info
        if ($versionInfo.IsBeta) {
            # Beta version like 6.20 beta 1 -> winrar-x64-620b1.exe
            if ($versionInfo.BaseVersion -match '(\d+)\.(\d+)') {
                $major = $matches[1]
                $minor = $matches[2].PadLeft(2, '0')
                $filename = "winrar-${arch}-${major}${minor}b$($versionInfo.BetaNumber).exe"
            }
        } else {
            # Stable version like 7.13 -> winrar-x64-713.exe
            if ($versionInfo.BaseVersion -match '(\d+)\.(\d+)') {
                $major = $matches[1]
                $minor = $matches[2].PadLeft(2, '0')
                $filename = "winrar-${arch}-${major}${minor}"
            }
        }

        if (-not $filename) {
            Write-Host "Unable to construct filename for version: $($versionInfo.DisplayName)"
            return $false
        }
        
        # Construct download URL
        $downloadUrl = "https://www.rarlab.com/rar/$filename"

        Write-Host "Downloading WinRAR $($versionInfo.DisplayName) from: $downloadUrl"
        
        $tempFile = Join-Path $env:TEMP $filename
        $webClient.DownloadFile($downloadUrl, $tempFile)

        if (Test-Path $tempFile) {
            Write-Host "Installing WinRAR $($versionInfo.DisplayName)..."
            
            # Run installer with silent parameters
            $installArgs = "/S /LANG=English"
            Start-Process -FilePath $tempFile -ArgumentList $installArgs -Wait

            Write-Host "WinRAR $($versionInfo.DisplayName) installed successfully!"
            
            # Clean up
            if (Test-Path $tempFile) { Remove-Item $tempFile -Recurse -Force -ErrorAction SilentlyContinue }

            return $true
        } else {
            Write-Host "Download failed - file not found"

            return $false
        }
        
    } catch {
        Write-Host "Failed to download/install WinRAR: $($_.Exception.Message)"

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

    $currentVersion = Get-CurrentWinRARVersion

    try {
        # --- Update WinRAR ---
        if($currentVersion) {
            
            $latestVersion = Get-LatestWinRARVersion
            
            if($latestVersion) {
                if([version]($latestVersion.Version) -gt [version]$currentVersion) {
                    Log "Starting update..."

                    $success = Install-WinRAR $latestVersion

                    if ($success) {
                        Log "WinRAR has been updated to version $($latestVersion.Version)"
                    } else {
                        Log "Failed to update WinRAR"

                        exit 1
                    }
                } else {
                    Log "WinRAR is already up to date (version $currentVersion)"
                }
             } else {
                Log "Could not retrieve latest version from rarlab.com"

                exit 1
             }
        } else {
            Log "WinRAR is not installed. Skipping update."
        }
    } catch {
        Log "ERROR: $($_.Exception.Message)"

        exit 1
    }
} else {
    Log "WinRAR is currently running. Skipping update."
}