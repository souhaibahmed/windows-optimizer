# ================================================================================
#  Windows Optimizer - Setup & Entry Point
#  by souhaibahmed
#  Usage: irm https://raw.githubusercontent.com/souhaibahmed/windows-optimizer/main/setup.ps1 | iex
# ================================================================================

# ── Enforce TLS 1.2 for all web requests ─────────────────────────────────────
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$BASE_URL  = "https://raw.githubusercontent.com/souhaibahmed/windows-optimizer/main"
$TEMP_FILE = "$env:TEMP\wopt_session.json"

# ── UI Helpers ────────────────────────────────────────────────────────────────
function Write-OK($msg)   { Write-Host "  [+] $msg" -ForegroundColor Green   }
function Write-Warn($msg) { Write-Host "  [!] $msg" -ForegroundColor Yellow  }
function Write-Info($msg) { Write-Host "  [~] $msg" -ForegroundColor Cyan    }
function Write-Err($msg)  { Write-Host "  [X] $msg" -ForegroundColor Red     }
function Write-Dim($msg)  { Write-Host "      $msg" -ForegroundColor DarkGray }

function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                                              ║" -ForegroundColor Cyan
    Write-Host "  ║         W I N D O W S  O P T I M I Z E R   ║" -ForegroundColor Cyan
    Write-Host "  ║                  v 2 . 0                    ║" -ForegroundColor Cyan
    Write-Host "  ║                                              ║" -ForegroundColor Cyan
    Write-Host "  ║              by  souhaibahmed               ║" -ForegroundColor Cyan
    Write-Host "  ║                                              ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

# ── 1. Admin check ────────────────────────────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $isAdmin) {
    Show-Banner
    Write-Err "This script must be run as Administrator."
    Write-Dim "Right-click PowerShell → Run as Administrator, then try again."
    Write-Host ""
    pause
    exit 1
}

# ── 2. Show banner + scanning message ────────────────────────────────────────
Show-Banner
Write-Host "  Scanning your system..." -ForegroundColor DarkGray
Write-Host ""

# ── 3. Detect Windows version ─────────────────────────────────────────────────
$osInfo      = Get-CimInstance -ClassName Win32_OperatingSystem
$buildNumber = [int]$osInfo.BuildNumber
$osCaption   = $osInfo.Caption.Trim()

if ($buildNumber -ge 22000) {
    $winVersion = "Windows 11"
} elseif ($buildNumber -ge 10240) {
    $winVersion = "Windows 10"
} else {
    Write-Err "Unsupported OS. This tool supports Windows 10 and Windows 11 only."
    pause; exit 1
}

Write-OK "OS detected: $osCaption (Build $buildNumber)"

# ── 4. Check PowerShell version ───────────────────────────────────────────────
$psVer = $PSVersionTable.PSVersion.Major
if ($psVer -ge 5) {
    Write-OK "PowerShell version: $psVer"
} else {
    Write-Warn "PowerShell $psVer is outdated. Version 5 or higher is recommended."
}

# ── 5. Check & fix Execution Policy ──────────────────────────────────────────
$execPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($execPolicy -in @('Restricted', 'AllSigned')) {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction SilentlyContinue
    Write-OK "Execution policy updated to: RemoteSigned"
} else {
    Write-OK "Execution policy: $execPolicy"
}

# ── 6. Check & attempt to enable winget ───────────────────────────────────────
$wingetAvailable = $false
$wingetVersion   = "N/A"

# First try: direct call
try {
    $wgRaw = winget --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $wingetAvailable = $true
        $wingetVersion   = ($wgRaw | Out-String).Trim()
    }
} catch { }

# Second try: re-register App Installer if not found
if (-not $wingetAvailable) {
    Write-Warn "winget not found. Trying to activate it..."
    try {
        $aiPkg = Get-AppxPackage -AllUsers -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue
        if ($aiPkg) {
            Add-AppxPackage -DisableDevelopmentMode -Register "$($aiPkg.InstallLocation)\AppxManifest.xml" -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            $wgRaw2 = winget --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                $wingetAvailable = $true
                $wingetVersion   = ($wgRaw2 | Out-String).Trim()
                Write-OK "winget activated: $wingetVersion"
            }
        }
    } catch { }

    if (-not $wingetAvailable) {
        Write-Warn "winget could not be enabled automatically."
        Write-Dim "Install 'App Installer' from the Microsoft Store to use the app-install feature."
    }
} else {
    Write-OK "winget: $wingetVersion"
}

# ── 7. Check Chocolatey (optional) ───────────────────────────────────────────
$chocoAvailable = $false
try {
    $chocoRaw = choco --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $chocoAvailable = $true
        Write-OK "Chocolatey: $($chocoRaw.ToString().Trim())"
    }
} catch { }

if (-not $chocoAvailable) {
    Write-Info "Chocolatey: not installed (optional)"
}

# ── 8. Detect hardware ────────────────────────────────────────────────────────
$gpuObj    = Get-CimInstance -ClassName Win32_VideoController | Select-Object -First 1
$gpuName   = $gpuObj.Name

$gpuVendor = switch -Regex ($gpuName) {
    "NVIDIA"       { "NVIDIA" }
    "AMD|Radeon"   { "AMD"    }
    "Intel"        { "Intel"  }
    default        { "Unknown" }
}

$ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)

Write-OK "GPU: $gpuName ($gpuVendor)"
Write-OK "RAM: ${ramGB} GB"

# ── 9. Save session info to temp file ─────────────────────────────────────────
$sessionData = [ordered]@{
    WinVersion      = $winVersion
    BuildNumber     = $buildNumber
    OsCaption       = $osCaption
    PsVersion       = $psVer
    WingetAvailable = $wingetAvailable
    WingetVersion   = $wingetVersion
    ChocoAvailable  = $chocoAvailable
    GpuName         = $gpuName
    GpuVendor       = $gpuVendor
    RamGB           = $ramGB
    CreatedAt       = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

try {
    $sessionData | ConvertTo-Json -Depth 3 | Out-File -FilePath $TEMP_FILE -Encoding UTF8 -Force
} catch {
    Write-Warn "Could not write session file. Some features may fall back to defaults."
}

# ── 10. Main menu ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  [1]  Optimize This PC" -ForegroundColor Green
Write-Host ""
Write-Host "  [0]  Exit" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  ────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

$choice = Read-Host "  Enter your choice"

switch ($choice) {
    "1" {
        Write-Host ""
        Write-Info "Loading Optimizer module..."
        Write-Host ""
        iex (irm "$BASE_URL/optimize.ps1")
    }
    "0" {
        Write-Host ""
        Write-Host "  Goodbye!" -ForegroundColor DarkGray
        Write-Host ""
    }
    default {
        Write-Err "Invalid choice. Run the script again."
    }
}

# ── Cleanup: delete temp session file ────────────────────────────────────────
if (Test-Path $TEMP_FILE) {
    Remove-Item $TEMP_FILE -Force -ErrorAction SilentlyContinue
}
