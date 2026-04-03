param([string]$CleanUp)

$ErrorActionPreference = "SilentlyContinue"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Custom {
    param([string]$Message, [string]$Color = "White")
    $host.UI.RawUI.ForegroundColor = $Color
    Write-Host $Message
    $host.UI.RawUI.ForegroundColor = "White"
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-SystemInfo {
    $os = Get-CimInstance Win32_OperatingSystem
    $build = [int]$os.BuildNumber
    if ($build -ge 22000) {
        $version = "Windows 11"
    } else {
        $version = "Windows 10"
    }

    $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
    $gpuName = $gpu.Name
    $gpuVendor = "Intel/Other"
    if ($gpuName -match "NVIDIA") { $gpuVendor = "NVIDIA" }
    elseif ($gpuName -match "AMD" -or $gpuName -match "Radeon") { $gpuVendor = "AMD" }

    $ram = [math]::Round($os.TotalVisibleMemorySize / 1MB)

    $psVersion = $PSVersionTable.PSVersion.Major

    $wingetAvailable = $false
    $wingetVersion = "N/A"
    try {
        $wingetCheck = & winget --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            $wingetAvailable = $true
            $wingetVersion = $wingetCheck
        }
    } catch {}

    $chocoAvailable = $false
    try {
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            $chocoAvailable = $true
        }
    } catch {}

    $session = @{
        WinVersion    = $version
        BuildNumber   = $build
        OsCaption     = $os.Caption
        PsVersion     = $psVersion
        WingetAvailable = $wingetAvailable
        WingetVersion  = $wingetVersion
        ChocoAvailable = $chocoAvailable
        GpuName       = $gpuName
        GpuVendor     = $gpuVendor
        RamGB         = $ram
        CreatedAt     = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }

    return $session
}

function Show-Banner {
    $host.UI.RawUI.ForegroundColor = "Cyan"
    Write-Host ""
    Write-Host "  ██╗    ██╗███████╗██╗      ██████╗ ██████╗ ███╗   ███╗██╗███╗   ██╗ █████╗ ██╗     "
    Write-Host "  ██║    ██║██╔════╝██║     ██╔════╝██╔═══██╗████╗ ████║██║████╗  ██║██╔══██╗██║     "
    Write-Host "  ██║ █╗ ██║█████╗  ██║     ██║     ██║   ██║██╔████╔██║██║██╔██╗ ██║███████║██║     "
    Write-Host "  ██║███╗██║██╔══╝  ██║     ██║     ██║   ██║██║╚██╔╝██║██║██║╚██╗██║██╔══██║██║     "
    Write-Host "  ╚███╔███╔╝███████╗███████╗╚██████╗╚██████╔╝██║ ╚═╝ ██║██║██║ ╚████║██║  ██║███████╗"
    Write-Host "   ╚══╝╚══╝ ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝"
    Write-Host ""
    $host.UI.RawUI.ForegroundColor = "DarkGray"
    Write-Host "  by souhaibahmed | v2.0 | PowerShell $($Session.PsVersion)"
    Write-Host ""
    $host.UI.RawUI.ForegroundColor = "White"
}

if (-not (Test-Administrator)) {
    Write-Custom "[X] Administrator privileges required. Please run as Administrator." "Red"
    Write-Custom "[>] Tip: Right-click → 'Run with PowerShell' or use: Start-Process powershell -Verb RunAs" "Yellow"
    pause
    exit 1
}

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Custom "[X] PowerShell 5.0+ required. Current version: $($PSVersionTable.PSVersion)" "Red"
    pause
    exit 1
}

$execPolicy = Get-ExecutionPolicy
if ($execPolicy -eq "Restricted") {
    Write-Custom "[!] Execution Policy is Restricted. Attempting to fix..." "Yellow"
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force
    Write-Custom "[+] Execution Policy set to RemoteSigned for this session." "Green"
}

$Session = Get-SystemInfo

$sessionFile = "$env:TEMP\wopt_session.json"
$Session | ConvertTo-Json -Depth 10 | Set-Content -Path $sessionFile -Encoding UTF8

Show-Banner

Write-Custom "[~] Detected: $($Session.WinVersion) (Build $($Session.BuildNumber))" "Cyan"
Write-Custom "[~] GPU: $($Session.GpuName)" "Cyan"
Write-Custom "[~] RAM: $($Session.RamGB) GB" "Cyan"
if ($Session.WingetAvailable) {
    Write-Custom "[~] winget: Available (v$($Session.WingetVersion))" "Cyan"
} else {
    Write-Custom "[~] winget: Not detected" "DarkGray"
}
if ($Session.ChocoAvailable) {
    Write-Custom "[~] Chocolatey: Available" "Cyan"
}
Write-Host ""

Write-Host "  [1] Optimize This PC" -ForegroundColor Green
Write-Host ""
Write-Host "  [0] Exit" -ForegroundColor DarkGray
Write-Host ""

$choice = Read-Host "  Select an option"

switch ($choice) {
    "1" {
        Write-Host ""
        Write-Custom "[>>] Loading optimization module..." "Yellow"
        Start-Sleep -Milliseconds 500
        $optimizeUrl = "https://raw.githubusercontent.com/souhaibahmed/windows-optimizer/main/optimize.ps1"
        iex(irm $optimizeUrl)
    }
    "0" {
        if (Test-Path $sessionFile) {
            Remove-Item $sessionFile -Force
        }
        Write-Host ""
        Write-Custom "[+] Session cleaned up. Goodbye!" "Green"
        exit 0
    }
    default {
        Write-Custom "[X] Invalid option. Please select 1 or 0." "Red"
        Start-Sleep -Seconds 2
        & $MyInvocation.MyCommand.Path
    }
}
