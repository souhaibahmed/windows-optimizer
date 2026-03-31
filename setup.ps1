# Windows Optimizer - by souhaibahmed
# Usage: irm https://raw.githubusercontent.com/souhaibahmed/windows-optimizer/main/setup.ps1 | iex

$base = "https://raw.githubusercontent.com/souhaibahmed/windows-optimizer/main"
$tempFile = "$env:TEMP\wo_sysinfo.tmp"

# =============================================
#           SYSTEM DETECTION
# =============================================

function Detect-System {
    $info = @{}

    # --- Windows Version ---
    $build = [System.Environment]::OSVersion.Version.Build
    if ($build -ge 22000) {
        $info.WindowsVersion = "Windows 11"
    } elseif ($build -ge 10240) {
        $info.WindowsVersion = "Windows 10"
    } else {
        $info.WindowsVersion = "Unknown"
    }
    $info.BuildNumber = $build

    # --- Architecture ---
    $info.Architecture = if ([System.Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }

    # --- winget ---
    $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetPath) {
        $info.WingetAvailable = $true
    } else {
        # Try to enable winget via App Installer (Windows 10/11)
        $info.WingetAvailable = $false
        try {
            $appInstaller = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller" -ErrorAction SilentlyContinue
            if ($appInstaller) {
                Add-AppxPackage -RegisterByFamilyName -MainPackage $appInstaller.PackageFamilyName -ErrorAction SilentlyContinue
                # Re-check after enabling
                $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
                if ($wingetPath) { $info.WingetAvailable = $true }
            }
        } catch {}
    }

    # --- Chocolatey ---
    $chocoPath = Get-Command choco -ErrorAction SilentlyContinue
    $info.ChocoAvailable = $null -ne $chocoPath

    # --- Scoop ---
    $scoopPath = Get-Command scoop -ErrorAction SilentlyContinue
    $info.ScoopAvailable = $null -ne $scoopPath

    # --- Admin Rights ---
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $info.IsAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    return $info
}

# =============================================
#           SHOW DETECTION RESULTS
# =============================================

function Show-SysInfo ($info) {
    $wingetStatus  = if ($info.WingetAvailable)  { "[OK]" } else { "[X]" }
    $chocoStatus   = if ($info.ChocoAvailable)   { "[OK]" } else { "[X]" }
    $scoopStatus   = if ($info.ScoopAvailable)   { "[OK]" } else { "[X]" }
    $adminStatus   = if ($info.IsAdmin)           { "[OK]" } else { "[!!] NOT Admin - some steps may fail" }

    Write-Host " System   : $($info.WindowsVersion) (Build $($info.BuildNumber)) [$($info.Architecture)]" -ForegroundColor White
    Write-Host " winget   : $wingetStatus" -ForegroundColor $(if ($info.WingetAvailable) { "Green" } else { "Red" })
    Write-Host " Chocolatey: $chocoStatus" -ForegroundColor $(if ($info.ChocoAvailable) { "Green" } else { "DarkGray" })
    Write-Host " Scoop    : $scoopStatus" -ForegroundColor $(if ($info.ScoopAvailable) { "Green" } else { "DarkGray" })
    Write-Host " Admin    : $adminStatus" -ForegroundColor $(if ($info.IsAdmin) { "Green" } else { "Yellow" })
}

# =============================================
#           SAVE TEMP FILE
# =============================================

function Save-TempInfo ($info) {
    $lines = @(
        "WindowsVersion=$($info.WindowsVersion)",
        "BuildNumber=$($info.BuildNumber)",
        "Architecture=$($info.Architecture)",
        "WingetAvailable=$($info.WingetAvailable)",
        "ChocoAvailable=$($info.ChocoAvailable)",
        "ScoopAvailable=$($info.ScoopAvailable)",
        "IsAdmin=$($info.IsAdmin)"
    )
    $lines | Set-Content -Path $tempFile -Encoding UTF8
}

# =============================================
#           CLEANUP TEMP FILE
# =============================================

function Cleanup-TempFile {
    if (Test-Path $tempFile) {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}

# =============================================
#           MAIN UI
# =============================================

Clear-Host

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║         Windows Optimizer  v2.0          ║" -ForegroundColor Cyan
Write-Host "  ║              by souhaibahmed             ║" -ForegroundColor DarkCyan
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Scanning your system..." -ForegroundColor DarkGray
Write-Host ""

$sysInfo = Detect-System
Save-TempInfo $sysInfo

Write-Host "  ┌──────────────────────────────────────────┐" -ForegroundColor DarkCyan
Write-Host "  │  System Info                             │" -ForegroundColor DarkCyan
Write-Host "  └──────────────────────────────────────────┘" -ForegroundColor DarkCyan
Show-SysInfo $sysInfo
Write-Host ""
Write-Host "  ══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "   [1]  Optimize This PC" -ForegroundColor Green
Write-Host ""
Write-Host "  ══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$choice = Read-Host "  Enter your choice"

switch ($choice.Trim()) {
    "1" {
        Write-Host ""
        Write-Host "  Loading Optimizer..." -ForegroundColor Green
        Write-Host ""
        try {
            iex (irm "$base/optimize.ps1")
        } finally {
            Cleanup-TempFile
        }
    }
    default {
        Write-Host ""
        Write-Host "  Invalid choice. Please run the script again." -ForegroundColor Red
        Cleanup-TempFile
    }
}
