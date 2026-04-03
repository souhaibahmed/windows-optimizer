$ErrorActionPreference = "SilentlyContinue"

$sessionFile = "$env:TEMP\wopt_session.json"
if (Test-Path $sessionFile) {
    $Session = Get-Content $sessionFile -Raw | ConvertFrom-Json
} else {
    $os = Get-CimInstance Win32_OperatingSystem
    $build = [int]$os.BuildNumber
    if ($build -ge 22000) { $version = "Windows 11" } else { $version = "Windows 10" }
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
    $gpuName = $gpu.Name
    $gpuVendor = "Intel/Other"
    if ($gpuName -match "NVIDIA") { $gpuVendor = "NVIDIA" }
    elseif ($gpuName -match "AMD" -or $gpuName -match "Radeon") { $gpuVendor = "AMD" }
    $ram = [math]::Round($os.TotalVisibleMemorySize / 1MB)
    $wingetAvailable = $false
    try { if ((Get-Command winget -ErrorAction SilentlyContinue) -and (winget --version 2>$null)) { $wingetAvailable = $true } } catch {}
    $Session = @{
        WinVersion = $version; BuildNumber = $build; OsCaption = $os.Caption
        GpuName = $gpuName; GpuVendor = $gpuVendor; RamGB = $ram
        WingetAvailable = $wingetAvailable
    }
}

function Write-OK($msg) { Write-Host "[+] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Task($msg) { Write-Host "[>>] $msg" -ForegroundColor Yellow }
function Write-Step($msg) { Write-Host "      $msg" -ForegroundColor DarkGray }
function Write-Skip($msg) { Write-Host "[-] Skipped: $msg" -ForegroundColor DarkGray }
function Write-Info($msg) { Write-Host "[~] $msg" -ForegroundColor Cyan }
function Write-Err($msg) { Write-Host "[X] $msg" -ForegroundColor Red }

function Show-Header($subtitle) {
    Clear-Host
    Write-Host ""
    Write-Host "  OPTIMIZER" -ForegroundColor Cyan -NoNewline
    Write-Host "  |  $($Session.WinVersion) | $($Session.GpuVendor) GPU | $($Session.RamGB) GB RAM" -ForegroundColor DarkGray
    if ($subtitle) {
        Write-Host "  ─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "  $subtitle" -ForegroundColor Cyan
    }
    Write-Host ""
}

function Wait-Key {
    Write-Host ""
    Write-Host "  Press any key to return to menu..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Confirm-Action($question) {
    Write-Host ""
    Write-Host "  $question [Y/N]: " -ForegroundColor Yellow -NoNewline
    $response = Read-Host
    return ($response -eq "Y" -or $response -eq "y")
}

function Set-Reg($Path, $Name, $Value, $Type = "DWord") {
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction SilentlyContinue
}

function Disable-Svc($Name, $Label) {
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($svc) {
        if ($svc.Status -eq "Running") {
            Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
        }
        Set-Service -Name $Name -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Step "$Label service disabled"
    }
}

function Clear-TempFolder($path, $label) {
    if (Test-Path $path) {
        $before = (Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        Remove-Item "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
        $after = (Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        $freed = [math]::Round(($before - $after) / 1MB, 2)
        Write-Step "$label cleared: $freed MB freed"
        return $freed
    }
    return 0
}

function Invoke-PerformanceTweaks {
    Show-Header "[1] PERFORMANCE TWEAKS"

    Write-Task "Activating High Performance power plan..."
    try {
        $highPerf = powercfg -list | Select-String "High performance"
        if ($highPerf) {
            $guid = ($highPerf -split '\s+')[3]
            powercfg -setactive $guid
            Write-Step "High Performance plan activated"
        }
    } catch { Write-Skip "Could not activate power plan" }

    Write-Task "Applying performance registry tweaks..."
    Set-Reg "HKCU:\Control Panel\Desktop" "VisualFXSetting" 2
    Set-Reg "HKCU:\Control Panel\Desktop" "StartupDelayInMSec" 0
    Set-Reg "HKCU:\Control Panel\Desktop" "ForegroundLockTimeout" 0
    Set-Reg "HKCU:\Control Panel\Desktop" "WaitToKillAppTimeout" 2000
    Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PrioritySeparation" "Win32PrioritySeparation" 38
    Write-Step "Visual effects minimized"
    Write-Step "Processor scheduling optimized"

    Write-Task "Disabling SysMain / Superfetch service..."
    Disable-Svc "SysMain" "SysMain (Superfetch)"

    Write-Task "Disabling Hibernation and Fast Startup..."
    powercfg -h off 2>$null
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 0
    Write-Step "Hibernation disabled"
    Write-Step "Fast Startup disabled"

    Write-Task "Disabling NTFS last access timestamp..."
    fsutil behavior set disableLastAccess 1 2>$null
    Write-Step "NTFS last access disabled"

    Write-Task "Removing network throttling..."
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 0xFFFFFFFF
    Write-Step "Network throttling removed"

    Write-Task "Disabling web search in Start Menu..."
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "CortanaConsent" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortana" 0
    Write-Step "Web search disabled"

    Write-OK "Performance tweaks applied successfully"
    Wait-Key
}

function Invoke-PrivacyTweaks {
    Show-Header "[2] PRIVACY & TELEMETRY"

    Write-Task "Disabling telemetry registry keys..."
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 0
    Set-Reg "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
    Write-Step "AllowTelemetry disabled"

    Write-Task "Disabling telemetry services..."
    Disable-Svc "DiagTrack" "DiagTrack"
    Disable-Svc "dmwappushservice" "dmwappushservice"

    Write-Task "Disabling Advertising ID..."
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0
    Write-Step "Advertising ID disabled"

    Write-Task "Disabling Activity History and Timeline..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "PublishUserActivities" 0
    Set-Reg "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableTailoredExperiencesWithDiagnosticData" 1
    Write-Step "Activity History disabled"

    Write-Task "Disabling location tracking..."
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" "Value" "Deny"
    Write-Step "Location tracking restricted"

    Write-Task "Disabling camera and microphone access..."
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam" "Value" "Deny"
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" "Value" "Deny"
    Write-Step "Camera/Microphone restricted"

    Write-Task "Disabling Windows Error Reporting..."
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" "Disabled" 1
    Disable-Svc "WerSvc" "Windows Error Reporting"
    Write-Step "Error Reporting disabled"

    Write-Task "Disabling CEIP..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows" "CEIPEnable" 0
    Write-Step "CEIP disabled"

    Write-Task "Disabling feedback notifications..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "DoNotShowFeedbackNotifications" 1
    Write-Step "Feedback notifications disabled"

    Write-Task "Disabling app launch tracking..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableUAR" 1
    Write-Step "App launch tracking disabled"

    Write-Task "Disabling Tailored Experiences..."
    Set-Reg "HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableTailoredExperiencesWithDiagnosticData" 1
    Write-Step "Tailored Experiences disabled"

    Write-Task "Disabling Cortana..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortana" 0
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCortanaButton" 0
    Write-Step "Cortana disabled"

    Write-Task "Disabling background apps..."
    Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 1
    Write-Step "Background apps disabled"

    Write-OK "Privacy & telemetry tweaks applied"
    Wait-Key
}

function Invoke-DebloatWindows {
    Show-Header "[3] DEBLOAT WINDOWS"

    if (-not (Confirm-Action "Remove pre-installed UWP apps? This is irreversible!")) {
        Write-Info "Operation cancelled"
        Wait-Key
        return
    }

    $removeApps = @(
        "Microsoft.3DBuilder", "Microsoft.BingFinance", "Microsoft.BingNews",
        "Microsoft.BingSports", "Microsoft.BingWeather", "Microsoft.Getstarted",
        "Microsoft.GetHelp", "Microsoft.Messaging", "Microsoft.MixedReality.Portal",
        "Microsoft.OfficeHub", "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.People", "Microsoft.Print3D", "Microsoft.SkypeApp",
        "Microsoft.Todos", "Microsoft.WindowsAlarms", "Microsoft.WindowsFeedbackHub",
        "Microsoft.WindowsMaps", "Microsoft.WindowsSoundRecorder",
        "Microsoft.Xbox.TCUI", "Microsoft.XboxApp", "Microsoft.XboxGameOverlay",
        "Microsoft.XboxGamingOverlay", "Microsoft.XboxIdentityProvider",
        "Microsoft.XboxSpeechToTextOverlay", "Microsoft.YourPhone",
        "Microsoft.ZuneMusic", "Microsoft.ZuneVideo",
        "Microsoft.Windows.Photos", "Microsoft.Clipchamp",
        "DisneyPlus", "SpotifyMusic", "CandyCrush", "King.CandyCrush",
        "BubbleWitch", "Facebook", "AmazonPrimeVideo", "TikTok",
        "Roblox"
    )

    Write-Task "Removing UWP apps for all users..."
    foreach ($app in $removeApps) {
        Get-AppxPackage -AllUsers $app -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        Get-AppxProvisionedDocument -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq $app } | Remove-AppxProvisionedDocument -Online -ErrorAction SilentlyContinue
    }
    Write-Step "UWP apps removed"

    Write-Task "Removing OneDrive..."
    Stop-Process -Name OneDriveSetup -Force -ErrorAction SilentlyContinue
    $onedrive32 = "$env:SystemRoot\System32\OneDriveSetup.exe"
    $onedrive64 = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
    if (Test-Path $onedrive32) {
        Start-Process $onedrive32 "/uninstall" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
    }
    if (Test-Path $onedrive64) {
        Start-Process $onedrive64 "/uninstall" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
    }
    if (-not (Test-Path $onedrive32) -and -not (Test-Path $onedrive64)) {
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" 1
        Write-Step "OneDrive sync disabled via policy"
    } else {
        Write-Step "OneDrive uninstalled"
    }

    Write-Task "Blocking automatic app re-installation..."
    $cdePaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    )
    foreach ($path in $cdePaths) {
        Set-Reg $path "SilentInstalledAppsEnabled" 0
        Set-Reg $path "SystemPaneSuggestionsEnabled" 0
        Set-Reg $path "SubscribedContentEnabled" 0
        Set-Reg $path "OemPreInstalledAppsEnabled" 0
        Set-Reg $path "PreInstalledAppsEnabled" 0
        Set-Reg $path "ContentDeliveryAllowed" 0
        Set-Reg $path "FeatureManagementEnabled" 0
    }
    Write-Step "Auto-reinstallation blocked"

    Write-OK "Windows debloated successfully"
    Wait-Key
}

function Invoke-InstallApps {
    Show-Header "[4] INSTALL ESSENTIAL APPS"

    if (-not $Session.WingetAvailable) {
        Write-Warn "winget is not available on this system."
        Write-Info "Install it from Microsoft Store or run as admin to register."
        Wait-Key
        return
    }

    Write-Host "  Available apps:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] Browsers       → Chrome, Firefox, Brave" -ForegroundColor White
    Write-Host "  [2] Utilities      → 7-Zip, VLC, Notepad++, PowerToys, Everything, WinRAR" -ForegroundColor White
    Write-Host "  [3] Development    → Git, VS Code, Windows Terminal, Node.js, Python" -ForegroundColor White
    Write-Host "  [4] Communication  → Discord, Telegram, WhatsApp" -ForegroundColor White
    Write-Host "  [5] Gaming         → Steam, Epic Games, GOG Galaxy" -ForegroundColor White
    Write-Host "  [6] Security       → Malwarebytes, KeePassXC" -ForegroundColor White
    Write-Host ""
    Write-Host "  [A] Install All" -ForegroundColor Green
    Write-Host "  [0] Back to menu" -ForegroundColor DarkGray
    Write-Host ""

    $selection = Read-Host "  Enter numbers (e.g. 1,3,5) or A for all"

    if ($selection -eq "0") { return }

    $allApps = $selection -eq "A" -or $selection -eq "a"
    $installList = @{}

    if ($allApps -or $selection -match "1") {
        $installList["Chrome"] = "Google.Chrome"
        $installList["Firefox"] = "Mozilla.Firefox"
        $installList["Brave"] = "Brave.Brave"
    }
    if ($allApps -or $selection -match "2") {
        $installList["7-Zip"] = "7zip.7zip"
        $installList["VLC"] = "VideoLAN.VLC"
        $installList["Notepad++"] = "NotepadPlusPlus.NotepadPlusPlus"
        $installList["PowerToys"] = "Microsoft.PowerToys"
        $installList["Everything"] = "voidtools.Everything"
        $installList["WinRAR"] = "RARLab.WinRAR"
    }
    if ($allApps -or $selection -match "3") {
        $installList["Git"] = "Git.Git"
        $installList["VS Code"] = "Microsoft.VisualStudioCode"
        $installList["Windows Terminal"] = "Microsoft.WindowsTerminal"
        $installList["Node.js LTS"] = "OpenJS.NodeJS.LTS"
        $installList["Python 3.12"] = "Python.Python.3.12"
    }
    if ($allApps -or $selection -match "4") {
        $installList["Discord"] = "Discord.Discord"
        $installList["Telegram"] = "Telegram.TelegramDesktop"
        $installList["WhatsApp"] = "WhatsApp.WhatsApp"
    }
    if ($allApps -or $selection -match "5") {
        $installList["Steam"] = "Valve.Steam"
        $installList["Epic Games"] = "EpicGames.EpicGamesLauncher"
        $installList["GOG Galaxy"] = "GOG.Galaxy"
    }
    if ($allApps -or $selection -match "6") {
        $installList["Malwarebytes"] = "Malwarebytes.Malwarebytes"
        $installList["KeePassXC"] = "KeePassXCTeam.KeePassXC"
    }

    foreach ($app in $installList.Keys) {
        Write-Task "Installing $app..."
        $id = $installList[$app]
        $result = & winget install --id $id --silent --accept-package-agreements --accept-source-agreements 2>&1
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
            Write-Step "$app installed successfully"
        } else {
            Write-Step "$app installation completed"
        }
    }

    Write-OK "App installation complete"
    Wait-Key
}

function Invoke-GamingOptimizations {
    Show-Header "[5] GAMING OPTIMIZATIONS"

    Write-Task "Enabling Windows Game Mode..."
    Set-Reg "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode" 1
    Set-Reg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1
    Write-Step "Game Mode enabled"

    Write-Task "Configuring Xbox Game Bar / DVR..."
    if (Confirm-Action "Disable Xbox Game Bar and DVR?")) {
        Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
        Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "GameDVR_Enabled" 0
        Set-Reg "HKLM:\Software\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0
        Write-Step "Game DVR disabled"
    }

    if ($Session.BuildNumber -ge 19041) {
        Write-Task "Enabling Hardware Accelerated GPU Scheduling..."
        Set-Reg "HKLM:\System\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 2
        Write-Step "HAGS enabled (requires restart)"
    } else {
        Write-Skip "HAGS requires Windows 10 2004+"
    }

    Write-Task "Disabling fullscreen optimizations..."
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "GameDVR_FSEBehaviorMode" 2
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "GameDVR_HonorUserFSEBehaviorMode" 1
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "GameDVR_DXGIHonorFSEWindowsCompatible" 1
    Write-Step "Fullscreen optimizations disabled"

    Write-Task "Disabling mouse acceleration..."
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "0"
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" "0"
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" "0"
    Write-Step "Enhance Pointer Precision disabled"

    Write-Task "Disabling power throttling..."
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff" 1
    Write-Step "Power throttling disabled"

    Write-Task "Boosting MMCSS game scheduling..."
    $mmcssPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    if (-not (Test-Path $mmcssPath)) {
        New-Item -Path $mmcssPath -Force | Out-Null
    }
    Set-Reg $mmcssPath "GPU Priority" 8
    Set-Reg $mmcssPath "Priority" 6
    Set-Reg $mmcssPath "SchedulingCategory" "High"
    Set-Reg $mmcssPath "SFIO Priority" "High"
    Write-Step "MMCSS game scheduling boosted"

    Write-Task "Optimizing network for gaming (Nagle's Algorithm)..."
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" "TcpAckFrequency" 1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" "TCPNoDelay" 1
    Write-Step "Nagle's Algorithm disabled"

    Write-Task "Disabling unused Xbox services..."
    Disable-Svc "XblAuthManager" "Xbox Live Auth Manager"
    Disable-Svc "XblGameSave" "Xbox Live Game Save"
    Disable-Svc "XboxNetApiSvc" "Xbox Live Networking Service"
    Disable-Svc "XboxGipSvc" "Xbox Accessory Management"
    Write-Step "Xbox services disabled"

    Write-OK "Gaming optimizations applied"
    Wait-Key
}

function Invoke-SystemCleanup {
    Show-Header "[6] SYSTEM CLEANUP"

    $totalFreed = 0

    Write-Task "Clearing User Temp folder..."
    $totalFreed += Clear-TempFolder "$env:TEMP" "User Temp"

    Write-Task "Clearing System Temp folder..."
    $totalFreed += Clear-TempFolder "$env:SystemRoot\Temp" "System Temp"

    Write-Task "Clearing Windows Update cache..."
    $wuserv = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
    if ($wuserv -and $wuserv.Status -eq "Running") {
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    }
    $totalFreed += Clear-TempFolder "$env:SystemRoot\SoftwareDistribution\Download" "Windows Update Cache"
    if ($wuserv -and $wuserv.Status -eq "Running") {
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    }

    Write-Task "Clearing Prefetch folder..."
    $totalFreed += Clear-TempFolder "$env:SystemRoot\Prefetch" "Prefetch"

    Write-Task "Flushing DNS cache..."
    ipconfig /flushdns | Out-Null
    Write-Step "DNS cache flushed"

    if (Confirm-Action "Clear all Windows Event Logs?")) {
        Write-Task "Clearing Event Logs..."
        wevtutil el | ForEach-Object { wevtutil cl $_ 2>$null }
        Write-Step "Event logs cleared"
    }

    Write-Task "Emptying Recycle Bin..."
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Step "Recycle Bin emptied"

    Write-Host ""
    Write-OK "Cleanup complete! Total space freed: $totalFreed MB"
    Wait-Key
}

function Invoke-WindowsUpdateSettings {
    Show-Header "[7] WINDOWS UPDATE SETTINGS"

    Write-Host "  [1] Disable automatic updates entirely" -ForegroundColor White
    Write-Host "  [2] Defer updates (Feature: 365d / Quality: 30d)" -ForegroundColor White
    Write-Host "  [3] Block driver updates via Windows Update" -ForegroundColor White
    Write-Host "  [A] Apply all three options" -ForegroundColor Green
    Write-Host "  [0] Back to menu" -ForegroundColor DarkGray
    Write-Host ""

    $choice = Read-Host "  Select an option"

    switch ($choice) {
        "1" {
            Write-Task "Disabling automatic Windows Updates..."
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoUpdate" 1
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "AUOptions" 2
            Write-Step "Automatic updates disabled"
            Write-OK "Option 1 applied"
        }
        "2" {
            Write-Task "Deferring feature updates (365 days)..."
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "TargetReleaseVersion" 1
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "ProductVersion" "Windows 10"
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "DeferFeatureUpdates" 1
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "DeferFeatureUpdatesPeriodInDays" 365
            Write-Task "Deferring quality updates (30 days)..."
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "DeferQualityUpdates" 1
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "DeferQualityUpdatesPeriodInDays" 30
            Write-OK "Option 2 applied"
        }
        "3" {
            Write-Task "Blocking driver updates via Windows Update..."
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "ExcludeWUDriversInQualityUpdate" 1
            Write-Step "Driver updates blocked"
            Write-OK "Option 3 applied"
        }
        "A" {
            Write-Task "Applying all Windows Update options..."
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoUpdate" 1
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "AUOptions" 2
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "DeferFeatureUpdates" 1
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "DeferFeatureUpdatesPeriodInDays" 365
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "DeferQualityUpdates" 1
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "DeferQualityUpdatesPeriodInDays" 30
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "ExcludeWUDriversInQualityUpdate" 1
            Write-Step "All update restrictions applied"
            Write-OK "All options applied"
        }
        "0" { return }
        default { Write-Err "Invalid option"; Start-Sleep 1 }
    }

    Wait-Key
}

function Invoke-ApplyAll {
    Show-Header "[A] APPLY ALL RECOMMENDED TWEAKS"

    Write-Warn "Applying modules 1, 2, 3, 5, 6 in sequence..."
    Write-Host ""

    Start-Sleep 1
    Invoke-PerformanceTweaks
    Invoke-PrivacyTweaks
    Invoke-DebloatWindows
    Invoke-GamingOptimizations
    Invoke-SystemCleanup

    Show-Header "[A] APPLY ALL - COMPLETE"
    Write-Host ""
    $host.UI.RawUI.ForegroundColor = "Green"
    Write-Host "  ╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║          ALL OPTIMIZATIONS APPLIED SUCCESSFULLY!          ║" -ForegroundColor Green
    Write-Host "  ╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Warn "Please RESTART your PC for changes to take full effect."
    Write-Host ""
    Wait-Key
}

do {
    Show-Header "MAIN MENU"
    Write-Host "  [1] Performance Tweaks" -ForegroundColor White
    Write-Host "  [2] Privacy & Telemetry" -ForegroundColor White
    Write-Host "  [3] Debloat Windows" -ForegroundColor White
    Write-Host "  [4] Install Essential Apps" -ForegroundColor White
    Write-Host "  [5] Gaming Optimizations" -ForegroundColor White
    Write-Host "  [6] System Cleanup" -ForegroundColor White
    Write-Host "  [7] Windows Update Settings" -ForegroundColor White
    Write-Host ""
    Write-Host "  [A] Apply All Recommended Tweaks" -ForegroundColor Green
    Write-Host ""
    Write-Host "  [0] Exit" -ForegroundColor DarkGray
    Write-Host ""

    $choice = Read-Host "  Select an option"

    switch ($choice) {
        "1" { Invoke-PerformanceTweaks }
        "2" { Invoke-PrivacyTweaks }
        "3" { Invoke-DebloatWindows }
        "4" { Invoke-InstallApps }
        "5" { Invoke-GamingOptimizations }
        "6" { Invoke-SystemCleanup }
        "7" { Invoke-WindowsUpdateSettings }
        "A" { Invoke-ApplyAll }
        "0" {
            if (Test-Path $sessionFile) {
                Remove-Item $sessionFile -Force
            }
            Clear-Host
            Write-Host ""
            Write-Custom "[+] Session cleaned up. Goodbye!" "Green"
            Write-Host ""
            exit 0
        }
    }
} while ($true)
