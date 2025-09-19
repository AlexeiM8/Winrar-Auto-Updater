# 💻 WinRAR Auto Updater (PowerShell)

This PowerShell script automates the process of checking for the latest version of WinRAR and updating it silently on your Windows system. No more manual downloads or installations - just run the script and stay up to date!

This repository includes three PowerShell-based approaches to automatically update WinRAR on Windows:

1. ✅ [Direct from rarlab.com](Auto-Update-Winrar-Rarlab/)
2. 🍫 [Using Chocolatey](Auto-Update-Winrar-Chocolately/)
3. 🪟 [Using Winget](Auto-Update-Winrar-Winget/)

Each method has its own strengths and trade-offs. Choose the one that best fits your system setup and update preferences.

Personally, I like the direct-from-rarlab.com method best.

---

## 📊 Comparison Table

| **Feature**| [Direct from RARLAB](Auto-Update-Winrar-Rarlab/)| [Using Chocolatey (`choco`)](Auto-Update-Winrar-Chocolately/)| [Using Winget (`winget`)](Auto-Update-Winrar-Winget/)|
|------------------------------------|---------------------------|-----------------------------|------------------------------|
| **Update speed**| 🔥🔥🔥 Fastest (same-day)| 🔥 Fast (same-day, or with a slight delay of about 1–3 days)| 🐢 Often delayed (days–weeks)|
| **Can install beta versions**| ✅ Yes (pulls directly from RARLAB, so you'll get beta versions too)| ❌ No (`choco` usually sticks to stable releases)| ❌ No (`winget` usually sticks to stable releases)|
| **Consistency**| ⭐⭐⭐  (May break if [rarlab.com](https://www.rarlab.com) changes its website or file naming format. But honestly, they've kept things stable for years)| ⭐⭐⭐⭐⭐  (Stable via package manager)| ⭐⭐⭐⭐⭐  (Stable via package manager)|
| **Version check before update**| ✅ Yes| ✅ Yes| ✅ Yes|
| **Requires package manager**| ❌ No| ✅ Yes (`choco`)| ✅ Yes (`winget`)|
| **Auto installs package manager**| ❌ No (Because we don't need)| ✅ Yes| ✅ Yes|
| **Silent install**| ✅ Yes| ✅ Yes| ✅ Yes|
| **Skips if WinRAR is running**| ✅ Yes| ✅ Yes| ✅ Yes|
| **Scheduled task support**| ✅ Yes| ✅ Yes| ✅ Yes|
| **Logging support**| ✅ Yes| ✅ Yes| ✅ Yes|

---

## 📄 Further information can be found in the README.md file located in each script's directory.

---