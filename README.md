# 💻 WinRAR Auto Updater (PowerShell)

This PowerShell script automates the process of checking for the latest version of WinRAR and updating it silently on your Windows system. No more manual downloads or installations - just run the script and stay up to date!

## 📦 Features

- Checks for the latest WinRAR version using `winget`
- Installs or updates WinRAR via `winget` (no manual downloads required)
- Automatically installs `winget` and its dependencies if missing
- Skips update if WinRAR is currently running to avoid conflicts
- Performs silent installation with no user interaction
- Optionally supports scheduled execution via Task Scheduler to run the update daily
- Logs all actions and outcomes to `C:\winrar-auto-update.log` for easy tracking

## 🛠️ Requirements

- Windows 10 or later
- PowerShell 5.1 or newer
- Internet connection
- Administrator privileges (for installation)

## 🚀 Usage

**Step 1: Download the script**  
Download and save the PowerShell script to a known location (e.g., `C:\Scripts\auto-update-winrar.ps1`).  

**Step 2: Run PowerShell as Administrator**  
To ensure proper installation and scheduling, open PowerShell with elevated privileges:  
- Press Win + X →  Select Windows PowerShell (Admin)  
- Or search for "PowerShell", right-click →  Run as administrator  

**Step 3: Choose Your Execution Mode and Run**  
You have two options depending on whether you want automatic daily updates or just a one-time update.  

**🔁 Option 1: Register Daily Auto-Update Task**  

This command will:

- Create a scheduled task to run the script every day
- Immediately run the update once

```
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\auto-update-winrar.ps1" -verb runAs -register
```

**🔁 Option 2: Run One-Time Update Only**  

This command will:

- Run the update once
- No scheduled task will be created

```
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\auto-update-winrar.ps1" -verb runAs
```

## ⚙️ Configuration

The script includes two configurable settings that allow you to tailor its behavior to your preferences:

### 🕒 Task Schedule Time

You can set the time of day when the scheduled task runs by modifying the `$time` variable:

```powershell
$time = [datetime]"03:00:00"  # Line 17
```

- Default is 03:00:00 (3:00 AM)
- You can change this to any valid time format (e.g., "08:30:00" for 8:30 AM)

### 📄 Log File Path

You can customize where the script saves its log output by modifying the `$logfile` variable:

```powershell
$logfile = "C:\winrar-auto-update.log"  # Line 254
```

- Default path is `C:\winrar-auto-update.log`
- Change this to any valid file path if you prefer a different location (e.g., `D:\Logs\winrar.log`)

These settings give you control over when the update runs and where its activity is recorded. Make sure to save the script after editing these values.

## 🔁 Code Workflow Overview

This script follows a structured process to ensure WinRAR is installed or updated seamlessly - even on systems without `winget` pre-installed.

### 🧩 Step-by-Step Breakdown

1. **Check for Winget**
   - The script first checks if the `winget` package manager is available on the system.

2. **Install Winget (if missing)**
   - If `winget` is not found:
     - Automatically downloads required dependencies:
       - `Microsoft.UI.Xaml.2.8_8`
       - `Microsoft.VCLibs.140.00.UWPDesktop`
     - Installs these dependencies silently using `Add-AppxPackage`
     - Downloads the latest `winget` release from GitHub
     - Installs `winget` manually via its `.msixbundle` installer

3. **Install or Update WinRAR**
   - Once `winget` is available:
     - Uses `winget install` or `winget upgrade` to install or update WinRAR to the latest version
     - Ensures the process is silent and user - friendly

This workflow ensures compatibility across a wide range of Windows setups - even those without access to the Microsoft Store or pre-installed package managers.

## ⚠️ Note & Limitations

While this script provides a convenient and automated way to keep WinRAR updated, there are a few caveats to be aware of:

- **Update Delay via Winget**  
  The script relies on `winget` to fetch and install the latest version of WinRAR. However, software updates published to `winget` often lag behind the official releases from the vendor (e.g., [rarlab.com](https://www.rarlab.com)) by several days or even weeks.

- **Upcoming Direct Installer Script**  
  To address this delay, a separate script is in development that will:
  - Download the latest WinRAR installer directly from the official website
  - Automatically compare the installed version on your system with the latest version on [rarlab.com](https://www.rarlab.com)
  - Skip update if you're already up to date
  - Perform silent installation with no user interaction required
  - Support scheduled daily updates via Task Scheduler

This alternative will ensure you're always running the most current version as soon as it's released - ideal for users who prioritize speed and precision over package manager convenience. Stay tuned!

---