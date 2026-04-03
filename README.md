# Windows Optimizer

A PowerShell-based Windows optimization tool to make your PC lean, fast, private, and gaming-ready.

## Quick Start

```powershell
irm https://raw.githubusercontent.com/souhaibahmed/windows-optimizer/main/setup.ps1 | iex
```

**Requires Administrator privileges.**

## Features

### [1] Performance Tweaks
- Activates High Performance power plan
- Minimizes visual effects
- Disables SysMain/Superfetch service
- Disables Hibernation and Fast Startup
- Disables NTFS last access timestamps
- Removes network throttling

### [2] Privacy & Telemetry
- Disables Windows telemetry
- Stops DiagTrack and dmwappushservice
- Disables Advertising ID
- Restricts camera and microphone access
- Disables Windows Error Reporting
- Disables Cortana and web search

### [3] Debloat Windows
- Removes 45+ pre-installed UWP apps
- Removes OneDrive
- Blocks automatic app re-installation

### [4] Install Essential Apps
- Browsers: Chrome, Firefox, Brave
- Utilities: 7-Zip, VLC, Notepad++, PowerToys, Everything, WinRAR
- Development: Git, VS Code, Windows Terminal, Node.js, Python
- Communication: Discord, Telegram, WhatsApp
- Gaming: Steam, Epic Games, GOG Galaxy
- Security: Malwarebytes, KeePassXC

### [5] Gaming Optimizations
- Enables Windows Game Mode
- Enables Hardware Accelerated GPU Scheduling
- Disables Xbox Game Bar/DVR
- Disables mouse acceleration
- Disables power throttling
- Boosts MMCSS game scheduling
- Optimizes network for gaming

### [6] System Cleanup
- Clears User and System Temp folders
- Clears Windows Update cache
- Clears Prefetch folder
- Flushes DNS cache
- Empties Recycle Bin

### [7] Windows Update Settings
- Disable automatic updates
- Defer feature/quality updates
- Block driver updates

## System Requirements

- Windows 10 (build 10240+) or Windows 11
- PowerShell 5.0+
- Administrator privileges

## Project Structure

```
windows-optimizer/
├── setup.ps1      # Entry point
├── optimize.ps1   # Main optimization modules
├── README.md
└── CREDITS.md
```

## License

MIT License

## Author

[souhaibahmed](https://github.com/souhaibahmed)
