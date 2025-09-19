# 💻 WinRAR Auto Updater Using Chocolately (PowerShell)

This PowerShell script automates the process of checking for the latest version of WinRAR and updating it silently on your Windows system. No more manual downloads or installations - just run the script and stay up to date!

## 📦 Features

- Checks for the latest WinRAR version using `chocolately`
- Checks for the installed WinRAR version on your computer using registry entries or the actual installation path
- Updates WinRAR via `chocolately` (no manual downloads required)
- Automatically installs `chocolately` if missing
- Only updates WinRAR if it's already installed
- Skips update if WinRAR is currently running to avoid conflicts
- Performs silent installation with no user interaction
- Optionally supports scheduled execution via Task Scheduler to run the update daily
- If your computer is offline when the task is scheduled, it will run the next time you log in
- Logs all actions and outcomes to `C:\winrar-auto-update.log` for easy tracking

## 🛠️ Requirements

- Windows 10 or later
- PowerShell 5.1 or newer
- Internet connection
- Administrator privileges (for installation)

## 🚀 Usage

**Step 1: Download the script**  
Download and save the PowerShell script to a known location (e.g., `C:\Scripts\auto-update-winrar-chocolately.ps1`).  

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
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\auto-update-winrar-chocolately.ps1" -verb runAs -register
```

**🔁 Option 2: Run One-Time Update Only**  

This command will:

- Run the update once
- No scheduled task will be created

```
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\auto-update-winrar-chocolately.ps1" -verb runAs
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

This script follows a structured process to ensure WinRAR is installed or updated seamlessly - even on systems without `chocolately` pre-installed.

### 🧩 Step-by-Step Breakdown

1. **Check for Chocolately**
   - The script first checks if the `chocolately` package manager is available on the system.

2. **Install Chocolately (if missing)**
   - If `chocolately` is not found:
     - Installs `chocolately` using [https://community.chocolatey.org/install.ps1](https://community.chocolatey.org/install.ps1)

3. **Update WinRAR**
   - Once `chocolately` is available:
     - Check if WinRAR is currently running; skip update to avoid conflicts
     - Check if WinRAR is installed; skip update if it's not
     - Uses `choco upgrade` to update WinRAR to the latest version
     - Ensures the process is silent and user - friendly

This workflow ensures compatibility across a wide range of Windows setups - even those without pre-installed package managers.

---