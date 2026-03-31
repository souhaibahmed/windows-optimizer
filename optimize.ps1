# ================================================================================
#  Windows Optimizer - Optimization Module
#  by souhaibahmed
#  Called from setup.ps1 via: iex (irm "$BASE_URL/optimize.ps1")
# ================================================================================

# ── Load session data (written by setup.ps1) ──────────────────────────────────
$TEMP_FILE = "$env:TEMP\wopt_session.json"
$Session   = $null

if (Test-Path $TEMP_FILE) {
    try { $Session = Get-Content $TEMP_FILE -Raw | ConvertFrom-Json } catch { }
}

# Fallback: detect on the fly if called directly (without setup.ps1)
if (-not $Session) {
    $osFb     = Get-CimInstance -ClassName Win32_OperatingSystem
    $bldFb    = [int]$osFb.BuildNumber
    $gpuFb    = (Get-CimInstance -ClassName Win32_VideoController | Select-Object -First 1).Name
    $Session  = [PSCustomObject]@{
        WinVersion      = if ($bldFb -ge 22000) { "Windows 11" } else { "Windows 10" }
        BuildNumber     = $bldFb
        OsCaption       = $osFb.Caption.Trim()
        PsVersion       = $PSVersionTable.PSVersion.Major
        WingetAvailable = $false
        WingetVersion   = "N/A"
        ChocoAvailable  = $false
        GpuName         = $gpuFb
        GpuVendor       = if ($gpuFb -match "NVIDIA") { "NVIDIA" } elseif ($gpuFb -match "AMD|Radeon") { "AMD" } else { "Intel/Other" }
        RamGB           = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
        CreatedAt       = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
}

# ── UI Helpers ────────────────────────────────────────────────────────────────
function Show-Header([string]$subtitle = "") {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║        W I N D O W S  O P T I M I Z E R     ║" -ForegroundColor Cyan
    Write-Host "  ║                  v 2 . 0                    ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
    $sysLine = "  $($Session.WinVersion)  |  GPU: $($Session.GpuVendor)  |  RAM: $($Session.RamGB) GB"
    Write-Host $sysLine -ForegroundColor DarkGray
    if ($subtitle) {
        Write-Host ""
        Write-Host "  ── $subtitle ──" -ForegroundColor Cyan
    }
    Write-Host ""
}

function Write-OK($msg)    { Write-Host "  [+] $msg" -ForegroundColor Green    }
function Write-Warn($msg)  { Write-Host "  [!] $msg" -ForegroundColor Yellow   }
function Write-Task($msg)  { Write-Host "  >>  $msg" -ForegroundColor Yellow   }
function Write-Step($msg)  { Write-Host "      $msg" -ForegroundColor Gray     }
function Write-Skip($msg)  { Write-Host "  [-] Skipped: $msg" -ForegroundColor DarkGray }

function Wait-Key {
    Write-Host ""
    Write-Host "  Press any key to return to the menu..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Confirm-Action([string]$question) {
    $ans = Read-Host "  $question [Y/N]"
    return ($ans -in @("Y", "y"))
}

# ── Registry Helper ───────────────────────────────────────────────────────────
function Set-Reg {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = "DWord"
    )
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction SilentlyContinue
    } catch { }
}

# ── Service Helper ─────────────────────────────────────────────────────────────
function Disable-Svc([string]$Name, [string]$Label) {
    try {
        $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if ($svc) {
            Stop-Service  -Name $Name -Force -ErrorAction SilentlyContinue
            Set-Service   -Name $Name -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Step "Service disabled: $Label"
        }
    } catch { }
}

# ════════════════════════════════════════════════════════════════════════════════
#  MODULE 1 ─ PERFORMANCE TWEAKS
# ════════════════════════════════════════════════════════════════════════════════
function Invoke-PerformanceTweaks {
    Show-Header "PERFORMANCE TWEAKS"

    # High Performance power plan
    Write-Task "Activating High Performance power plan..."
    $hpGuid = (powercfg -l | Select-String "High performance" | ForEach-Object {
        ($_ -split '\s+')[3]
    } | Select-Object -First 1)
    if ($hpGuid) {
        powercfg -setactive $hpGuid 2>$null
        Write-Step "Power plan: High Performance"
    } else {
        powercfg -setactive SCHEME_MIN 2>$null
        Write-Step "Power plan: Maximum Performance (fallback)"
    }

    # Visual effects: performance mode
    Write-Task "Minimizing visual effects..."
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2
    Set-Reg "HKCU:\Control Panel\Desktop"                                             "MenuShowDelay"   "0"   "String"
    Set-Reg "HKCU:\Control Panel\Desktop\WindowMetrics"                              "MinAnimate"      "0"   "String"
    Set-Reg "HKCU:\Software\Microsoft\Windows\DWM"                                   "EnableAeroPeek"  0
    Write-Step "Visual effects minimized"

    # Remove startup animation / delay
    Write-Task "Removing startup delay..."
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"       "EnableFirstLogonAnimation" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" "StartupDelayInMSec"       0
    Write-Step "Startup delay removed"

    # Disable SysMain (Superfetch) – not needed on SSDs
    Write-Task "Disabling SysMain / Superfetch..."
    Disable-Svc "SysMain" "SysMain (Superfetch)"

    # Processor scheduling: favor foreground programs
    Write-Task "Optimizing processor scheduling..."
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 38
    Write-Step "Foreground programs get scheduling priority"

    # Disable Hibernation (frees hiberfil.sys)
    Write-Task "Disabling Hibernation..."
    powercfg -h off 2>$null
    Write-Step "Hibernation disabled (hiberfil.sys removed)"

    # Disable Fast Startup (causes issues with true shutdown)
    Write-Task "Disabling Fast Startup..."
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 0
    Write-Step "Fast Startup disabled"

    # NTFS: disable last access time updates
    Write-Task "Disabling NTFS last access timestamp..."
    fsutil behavior set disablelastaccess 1 | Out-Null
    Write-Step "Last access time tracking disabled"

    # Disable network throttling
    Write-Task "Removing network throttling..."
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 0xFFFFFFFF
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness"   0
    Write-Step "Network throttling disabled"

    # Disable search web in Start Menu (local search only, faster)
    Write-Task "Disabling web search in Start Menu..."
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "CortanaConsent"    0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "DisableWebSearch" 1
    Write-Step "Start Menu web search disabled"

    Write-Host ""
    Write-OK "Performance tweaks applied."
    Wait-Key
}

# ════════════════════════════════════════════════════════════════════════════════
#  MODULE 2 ─ PRIVACY & TELEMETRY
# ════════════════════════════════════════════════════════════════════════════════
function Invoke-PrivacyTweaks {
    Show-Header "PRIVACY & TELEMETRY"

    # Telemetry data collection
    Write-Task "Disabling telemetry collection..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"                  "AllowTelemetry" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"   "AllowTelemetry" 0
    Set-Reg "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 0
    Disable-Svc "DiagTrack"       "Connected User Experiences & Telemetry"
    Disable-Svc "dmwappushservice" "Device Management WAP Push"
    Write-Step "Telemetry: disabled"

    # Advertising ID
    Write-Task "Disabling Advertising ID..."
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"    "Enabled"                 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"           "DisabledByGroupPolicy"   1
    Write-Step "Advertising ID: disabled"

    # Activity History / Timeline
    Write-Task "Disabling Activity History..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed"    0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "PublishUserActivities" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "UploadUserActivities"  0
    Write-Step "Activity history: disabled"

    # Location tracking
    Write-Task "Disabling location tracking..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableLocation" 1
    Write-Step "Location tracking: disabled"

    # App access to camera/microphone (restricted to explicit consent)
    Write-Task "Restricting camera & microphone access for apps..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessCamera"     2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessMicrophone" 2
    Write-Step "Camera & microphone: apps require explicit permission"

    # Windows Error Reporting
    Write-Task "Disabling Windows Error Reporting..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" "Disabled" 1
    Disable-Svc "WerSvc" "Windows Error Reporting"
    Write-Step "Error reporting: disabled"

    # CEIP (Customer Experience Improvement Program)
    Write-Task "Disabling CEIP..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows" "CEIPEnable" 0
    Write-Step "CEIP: disabled"

    # Feedback notifications
    Write-Task "Disabling feedback requests..."
    Set-Reg "HKCU:\Software\Microsoft\Siuf\Rules"                               "NumberOfSIUFInPeriod"       0
    Set-Reg "HKCU:\Software\Microsoft\Siuf\Rules"                               "PeriodInNanoSeconds"        0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"           "DoNotShowFeedbackNotifications" 1
    Write-Step "Feedback prompts: disabled"

    # App launch tracking
    Write-Task "Disabling app launch tracking..."
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 0
    Write-Step "App tracking: disabled"

    # Tailored experiences
    Write-Task "Disabling tailored experiences..."
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesWithDiagnosticDataEnabled" 0
    Write-Step "Tailored experiences: disabled"

    # Cortana
    Write-Task "Disabling Cortana..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortana" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"   "CortanaConsent" 0
    Write-Step "Cortana: disabled"

    # Disable apps running in background
    Write-Task "Disabling background app execution..."
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 1
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BackgroundAppGlobalToggle" 0
    Write-Step "Background app execution: disabled"

    Write-Host ""
    Write-OK "Privacy & telemetry tweaks applied."
    Wait-Key
}

# ════════════════════════════════════════════════════════════════════════════════
#  MODULE 3 ─ DEBLOAT WINDOWS
# ════════════════════════════════════════════════════════════════════════════════
function Invoke-Debloat {
    Show-Header "DEBLOAT WINDOWS"

    Write-Host "  Removes pre-installed bloatware apps." -ForegroundColor DarkGray
    Write-Host "  Core apps (Calculator, Notepad, Photos, etc.) are kept." -ForegroundColor DarkGray
    Write-Host ""

    if (-not (Confirm-Action "Proceed with debloat?")) {
        Write-Skip "Cancelled by user"
        Wait-Key
        return
    }

    $bloatList = @(
        "Microsoft.3DBuilder",
        "Microsoft.549981C3F5F10",           # Cortana standalone app
        "Microsoft.BingFinance",
        "Microsoft.BingFoodAndDrink",
        "Microsoft.BingHealthAndFitness",
        "Microsoft.BingNews",
        "Microsoft.BingSports",
        "Microsoft.BingTranslator",
        "Microsoft.BingTravel",
        "Microsoft.BingWeather",
        "Microsoft.Getstarted",
        "Microsoft.GetHelp",
        "Microsoft.Messaging",
        "Microsoft.Microsoft3DViewer",
        "Microsoft.MicrosoftOfficeHub",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.MixedReality.Portal",
        "Microsoft.NetworkSpeedTest",
        "Microsoft.News",
        "Microsoft.Office.Sway",
        "Microsoft.OneConnect",
        "Microsoft.People",
        "Microsoft.Print3D",
        "Microsoft.SkypeApp",
        "Microsoft.Teams",
        "Microsoft.Todos",
        "Microsoft.WindowsAlarms",
        "Microsoft.WindowsFeedbackHub",
        "Microsoft.WindowsMaps",
        "Microsoft.WindowsSoundRecorder",
        "Microsoft.Xbox.TCUI",
        "Microsoft.XboxApp",
        "Microsoft.XboxGameOverlay",
        "Microsoft.XboxGamingOverlay",
        "Microsoft.XboxIdentityProvider",
        "Microsoft.XboxSpeechToTextOverlay",
        "Microsoft.YourPhone",
        "Microsoft.ZuneMusic",
        "Microsoft.ZuneVideo",
        "MicrosoftTeams",
        "Clipchamp.Clipchamp",
        "Disney.37853D22215B2",
        "SpotifyAB.SpotifyMusic",
        "king.com.CandyCrushSaga",
        "king.com.CandyCrushFriends",
        "king.com.BubbleWitch3Saga",
        "Facebook.Facebook",
        "AmazonVideo.PrimeVideo",
        "BytedancePte.Ltd.TikTok",
        "ROBLOXCORPORATION.ROBLOX"
    )

    Write-Task "Removing bloatware packages..."
    $removed = 0; $skipped = 0

    foreach ($appName in $bloatList) {
        $pkg = Get-AppxPackage -AllUsers -Name $appName -ErrorAction SilentlyContinue
        if ($pkg) {
            try {
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
                # Remove provisioned package so it won't reinstall for new user profiles
                $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                        Where-Object { $_.DisplayName -eq $appName }
                if ($prov) {
                    Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction SilentlyContinue
                }
                Write-Step "Removed: $appName"
                $removed++
            } catch { $skipped++ }
        }
    }

    # OneDrive
    Write-Task "Removing OneDrive..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" 1
    $odProc = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
    if ($odProc) { $odProc | Stop-Process -Force -ErrorAction SilentlyContinue }
    $odPath64 = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
    $odPath32 = "$env:SystemRoot\System32\OneDriveSetup.exe"
    $odSetup  = if (Test-Path $odPath64) { $odPath64 } elseif (Test-Path $odPath32) { $odPath32 } else { $null }
    if ($odSetup) {
        Start-Process $odSetup "/uninstall" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
        Write-Step "OneDrive: uninstalled"
    } else {
        Write-Step "OneDrive: policy restriction applied"
    }

    # Block automatic re-installation of suggested apps
    Write-Task "Blocking automatic app re-installation..."
    $cdmPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    $cdmKeys = @(
        "SilentInstalledAppsEnabled", "SystemPaneSuggestionsEnabled",
        "SubscribedContentEnabled",   "OemPreInstalledAppsEnabled",
        "PreInstalledAppsEnabled",    "ContentDeliveryAllowed",
        "FeatureManagementEnabled"
    )
    foreach ($k in $cdmKeys) { Set-Reg $cdmPath $k 0 }
    Write-Step "Suggested app auto-install: blocked"

    Write-Host ""
    Write-OK "Debloat complete. Removed: $removed | Already gone: $skipped"
    Wait-Key
}

# ════════════════════════════════════════════════════════════════════════════════
#  MODULE 4 ─ INSTALL APPS (via winget)
# ════════════════════════════════════════════════════════════════════════════════
function Invoke-InstallApps {
    Show-Header "INSTALL ESSENTIAL APPS"

    if (-not $Session.WingetAvailable) {
        Write-Warn "winget is not available on this system."
        Write-Step "Install 'App Installer' from the Microsoft Store, then re-run setup."
        Wait-Key
        return
    }

    # App catalogue grouped by category
    # Format: [display index] -> @{ Name; Id }
    $catalogue = [ordered]@{
        "Browsers" = @(
            @{ Name="Google Chrome";         Id="Google.Chrome"                    }
            @{ Name="Mozilla Firefox";       Id="Mozilla.Firefox"                  }
            @{ Name="Brave Browser";         Id="Brave.Brave"                      }
        )
        "Utilities" = @(
            @{ Name="7-Zip";                 Id="7zip.7zip"                        }
            @{ Name="VLC Media Player";      Id="VideoLAN.VLC"                     }
            @{ Name="Notepad++";             Id="Notepad++.Notepad++"              }
            @{ Name="Microsoft PowerToys";   Id="Microsoft.PowerToys"              }
            @{ Name="Everything (Search)";   Id="voidtools.Everything"             }
            @{ Name="WinRAR";                Id="RARLab.WinRAR"                    }
        )
        "Development" = @(
            @{ Name="Git";                   Id="Git.Git"                          }
            @{ Name="Visual Studio Code";    Id="Microsoft.VisualStudioCode"       }
            @{ Name="Windows Terminal";      Id="Microsoft.WindowsTerminal"        }
            @{ Name="Node.js LTS";           Id="OpenJS.NodeJS.LTS"               }
            @{ Name="Python 3";              Id="Python.Python.3.12"              }
        )
        "Communication" = @(
            @{ Name="Discord";               Id="Discord.Discord"                  }
            @{ Name="Telegram Desktop";      Id="Telegram.TelegramDesktop"         }
            @{ Name="WhatsApp";              Id="WhatsApp.WhatsApp"                }
        )
        "Gaming" = @(
            @{ Name="Steam";                 Id="Valve.Steam"                      }
            @{ Name="Epic Games Launcher";   Id="EpicGames.EpicGamesLauncher"      }
            @{ Name="GOG Galaxy";            Id="GOG.Galaxy"                       }
        )
        "Security" = @(
            @{ Name="Malwarebytes";          Id="Malwarebytes.Malwarebytes"        }
            @{ Name="KeePassXC";             Id="KeePassXCTeam.KeePassXC"          }
        )
    }

    # Render menu
    $indexMap = @{}
    $counter  = 1

    foreach ($group in $catalogue.GetEnumerator()) {
        Write-Host "  $($group.Key):" -ForegroundColor Cyan
        foreach ($app in $group.Value) {
            Write-Host ("  [{0,2}] {1}" -f $counter, $app.Name) -ForegroundColor White
            $indexMap[$counter] = $app
            $counter++
        }
        Write-Host ""
    }

    Write-Host "  [A]  Install ALL apps above" -ForegroundColor Green
    Write-Host "  [0]  Back to menu"           -ForegroundColor DarkGray
    Write-Host ""

    $input = Read-Host "  Enter numbers separated by commas (e.g. 1,3,5) or A"

    if ($input -eq "0") { return }

    $toInstall = @()
    if ($input -match "^[Aa]$") {
        $toInstall = $indexMap.Values
    } else {
        $nums = $input -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -match "^\d+$" }
        foreach ($n in $nums) {
            $ni = [int]$n
            if ($indexMap.ContainsKey($ni)) { $toInstall += $indexMap[$ni] }
        }
    }

    if ($toInstall.Count -eq 0) {
        Write-Warn "No valid apps selected."
        Wait-Key
        return
    }

    Write-Host ""
    Write-Task "Installing $($toInstall.Count) app(s) silently..."
    Write-Host ""

    foreach ($app in $toInstall) {
        Write-Host "  >> $($app.Name)..." -NoNewline -ForegroundColor Yellow
        $out = winget install --id $app.Id --silent --accept-package-agreements --accept-source-agreements 2>&1
        # Exit code -1978335189 means "already installed"
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
            Write-Host " OK" -ForegroundColor Green
        } else {
            Write-Host " FAILED (code: $LASTEXITCODE)" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-OK "App installation finished."
    Wait-Key
}

# ════════════════════════════════════════════════════════════════════════════════
#  MODULE 5 ─ GAMING OPTIMIZATIONS
# ════════════════════════════════════════════════════════════════════════════════
function Invoke-GamingTweaks {
    Show-Header "GAMING OPTIMIZATIONS"
    Write-Host "  GPU: $($Session.GpuName)" -ForegroundColor DarkGray
    Write-Host ""

    # Enable Windows Game Mode
    Write-Task "Enabling Windows Game Mode..."
    Set-Reg "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode"  1
    Set-Reg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1
    Write-Step "Game Mode: enabled"

    # Xbox Game Bar / GameDVR
    Write-Task "Configuring Xbox Game Bar..."
    if (Confirm-Action "Disable Xbox Game Bar? (can eliminate stutter for some games)") {
        Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
        Set-Reg "HKCU:\System\GameConfigStore"                             "GameDVR_Enabled"   0
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"        "AllowGameDVR"      0
        Write-Step "Xbox Game Bar / DVR: disabled"
    } else {
        Write-Skip "Game Bar left enabled"
    }

    # Hardware Accelerated GPU Scheduling (Win10 2004 / Win11+)
    if ($Session.BuildNumber -ge 19041) {
        Write-Task "Enabling Hardware Accelerated GPU Scheduling (HAGS)..."
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 2
        Write-Step "HAGS: enabled (requires restart)"
    }

    # Disable fullscreen optimizations
    Write-Task "Disabling fullscreen optimizations..."
    Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode"                2
    Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_HonorUserFSEBehaviorMode"       1
    Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_DXGIHonorFSEWindowsCompatible" 1
    Write-Step "Fullscreen optimizations: disabled"

    # Disable mouse acceleration (pointer precision)
    Write-Task "Disabling mouse acceleration (Enhance Pointer Precision)..."
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed"      "0" "String"
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" "0" "String"
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" "0" "String"
    Write-Step "Mouse acceleration: disabled (raw input)"

    # Disable CPU/GPU power throttling
    Write-Task "Disabling power throttling for maximum GPU/CPU performance..."
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff" 1
    Write-Step "Power throttling: disabled"

    # Game scheduling (MMCSS)
    Write-Task "Boosting MMCSS game scheduling priority..."
    $mmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    Set-Reg $mmPath "Affinity"            0
    Set-Reg $mmPath "Background Only"     "False"  "String"
    Set-Reg $mmPath "Clock Rate"          10000
    Set-Reg $mmPath "GPU Priority"        8
    Set-Reg $mmPath "Priority"            6
    Set-Reg $mmPath "Scheduling Category" "High"   "String"
    Set-Reg $mmPath "SFIO Priority"       "High"   "String"
    Write-Step "MMCSS game tasks: High priority"

    # Disable Nagle's algorithm (lower ping in online games)
    Write-Task "Disabling Nagle's Algorithm for lower network latency..."
    $tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    Set-Reg $tcpPath "TcpAckFrequency" 1
    Set-Reg $tcpPath "TCPNoDelay"      1
    Write-Step "Nagle's Algorithm: disabled"

    # Disable unnecessary Xbox background services
    Write-Task "Disabling unused Xbox background services..."
    Disable-Svc "XblAuthManager"  "Xbox Live Auth Manager"
    Disable-Svc "XblGameSave"     "Xbox Live Game Save"
    Disable-Svc "XboxNetApiSvc"   "Xbox Live Networking"
    Disable-Svc "XboxGipSvc"      "Xbox Accessory Management"

    Write-Host ""
    Write-OK "Gaming optimizations applied. Restart your PC for full effect."
    Wait-Key
}

# ════════════════════════════════════════════════════════════════════════════════
#  MODULE 6 ─ SYSTEM CLEANUP
# ════════════════════════════════════════════════════════════════════════════════
function Invoke-SystemCleanup {
    Show-Header "SYSTEM CLEANUP"

    $totalFreedMB = 0

    # User Temp
    Write-Task "Clearing User Temp folder..."
    $sz = (Get-ChildItem "$env:TEMP" -Recurse -Force -ErrorAction SilentlyContinue |
           Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    $mb = [math]::Round($sz / 1MB, 1); $totalFreedMB += $mb
    Write-Step "User Temp: ~${mb} MB cleared"

    # System Temp
    Write-Task "Clearing System Temp folder..."
    $sz2 = (Get-ChildItem "C:\Windows\Temp" -Recurse -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    Remove-Item "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    $mb2 = [math]::Round($sz2 / 1MB, 1); $totalFreedMB += $mb2
    Write-Step "System Temp: ~${mb2} MB cleared"

    # Windows Update download cache
    Write-Task "Clearing Windows Update cache..."
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    $sz3 = (Get-ChildItem "C:\Windows\SoftwareDistribution\Download" -Recurse -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    Remove-Item "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    $mb3 = [math]::Round($sz3 / 1MB, 1); $totalFreedMB += $mb3
    Write-Step "WU cache: ~${mb3} MB cleared"

    # Prefetch
    Write-Task "Clearing Prefetch..."
    Remove-Item "C:\Windows\Prefetch\*" -Force -ErrorAction SilentlyContinue
    Write-Step "Prefetch cleared"

    # DNS cache
    Write-Task "Flushing DNS cache..."
    ipconfig /flushdns | Out-Null
    Write-Step "DNS cache flushed"

    # Event logs (optional)
    if (Confirm-Action "Clear all Windows Event Logs?") {
        Write-Task "Clearing Event Logs..."
        $logs = Get-WinEvent -ListLog * -ErrorAction SilentlyContinue |
                Where-Object { $_.IsEnabled -and $_.RecordCount -gt 0 }
        foreach ($log in $logs) {
            try {
                [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog($log.LogName)
            } catch { }
        }
        Write-Step "Event logs cleared"
    } else {
        Write-Skip "Event logs"
    }

    # Recycle Bin
    Write-Task "Emptying Recycle Bin..."
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Step "Recycle Bin emptied"

    Write-Host ""
    Write-OK "Cleanup complete. ~$totalFreedMB MB freed."
    Wait-Key
}

# ════════════════════════════════════════════════════════════════════════════════
#  MODULE 7 ─ WINDOWS UPDATE SETTINGS
# ════════════════════════════════════════════════════════════════════════════════
function Invoke-UpdateSettings {
    Show-Header "WINDOWS UPDATE SETTINGS"

    Write-Host "  [1]  Disable automatic updates (manual control only)"     -ForegroundColor White
    Write-Host "  [2]  Defer feature updates 365 days / quality 30 days"    -ForegroundColor White
    Write-Host "  [3]  Block driver updates via Windows Update"              -ForegroundColor White
    Write-Host "  [A]  Apply all three options above"                        -ForegroundColor Green
    Write-Host "  [0]  Back"                                                 -ForegroundColor DarkGray
    Write-Host ""

    $opt = Read-Host "  Choice"
    $all = $opt -in @("A","a")

    if ($opt -eq "1" -or $all) {
        Write-Task "Disabling automatic Windows Updates..."
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoUpdate" 1
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "AUOptions"    2
        Write-Step "Automatic updates: disabled"
    }
    if ($opt -eq "2" -or $all) {
        Write-Task "Deferring updates..."
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "DeferFeatureUpdates"             1
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "DeferFeatureUpdatesPeriodInDays" 365
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "DeferQualityUpdates"             1
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "DeferQualityUpdatesPeriodInDays" 30
        Write-Step "Feature updates deferred: 365 days | Quality updates: 30 days"
    }
    if ($opt -eq "3" -or $all) {
        Write-Task "Blocking driver updates via Windows Update..."
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "ExcludeWUDriversInQualityUpdate" 1
        Write-Step "Driver updates via WU: blocked"
    }
    if ($opt -eq "0") { return }

    Write-Host ""
    Write-OK "Update settings applied."
    Wait-Key
}

# ════════════════════════════════════════════════════════════════════════════════
#  APPLY ALL RECOMMENDED TWEAKS
# ════════════════════════════════════════════════════════════════════════════════
function Invoke-ApplyAll {
    Show-Header "APPLY ALL RECOMMENDED TWEAKS"

    Write-Host "  This will run all modules in sequence:" -ForegroundColor DarkGray
    Write-Host "   1. Performance Tweaks"     -ForegroundColor Gray
    Write-Host "   2. Privacy & Telemetry"    -ForegroundColor Gray
    Write-Host "   3. Debloat Windows"        -ForegroundColor Gray
    Write-Host "   4. Gaming Optimizations"   -ForegroundColor Gray
    Write-Host "   5. System Cleanup"         -ForegroundColor Gray
    Write-Host ""
    Write-Host "  App installation is excluded (run manually from the menu)." -ForegroundColor DarkYellow
    Write-Host ""

    if (-not (Confirm-Action "Proceed with full optimization?")) {
        Write-Skip "Cancelled"
        Wait-Key
        return
    }

    Invoke-PerformanceTweaks
    Invoke-PrivacyTweaks
    Invoke-Debloat
    Invoke-GamingTweaks
    Invoke-SystemCleanup

    Show-Header "ALL DONE"
    Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║                                              ║" -ForegroundColor Green
    Write-Host "  ║   All tweaks applied successfully!           ║" -ForegroundColor Green
    Write-Host "  ║   Please RESTART your PC to apply all        ║" -ForegroundColor Green
    Write-Host "  ║   registry and system changes.               ║" -ForegroundColor Green
    Write-Host "  ║                                              ║" -ForegroundColor Green
    Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Wait-Key
}

# ════════════════════════════════════════════════════════════════════════════════
#  MAIN MENU LOOP
# ════════════════════════════════════════════════════════════════════════════════
do {
    Show-Header "OPTIMIZATION MENU"

    Write-Host "  [1]  Performance Tweaks"          -ForegroundColor White
    Write-Host "  [2]  Privacy & Telemetry"          -ForegroundColor White
    Write-Host "  [3]  Debloat Windows"              -ForegroundColor White
    Write-Host "  [4]  Install Essential Apps"       -ForegroundColor White
    Write-Host "  [5]  Gaming Optimizations"         -ForegroundColor White
    Write-Host "  [6]  System Cleanup"               -ForegroundColor White
    Write-Host "  [7]  Windows Update Settings"      -ForegroundColor White
    Write-Host ""
    Write-Host "  [A]  Apply All Recommended Tweaks" -ForegroundColor Green
    Write-Host ""
    Write-Host "  [0]  Exit"                         -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  ────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""

    $menuInput = Read-Host "  Enter your choice"

    switch ($menuInput) {
        "1"            { Invoke-PerformanceTweaks }
        "2"            { Invoke-PrivacyTweaks     }
        "3"            { Invoke-Debloat           }
        "4"            { Invoke-InstallApps       }
        "5"            { Invoke-GamingTweaks      }
        "6"            { Invoke-SystemCleanup     }
        "7"            { Invoke-UpdateSettings    }
        { $_ -in @("A","a") } { Invoke-ApplyAll  }
        "0"            { break                    }
        default {
            Write-Host "  Invalid choice. Try again." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }

} while ($menuInput -ne "0")

Write-Host ""
Write-Host "  ── Session ended. Remember to restart your PC. ──" -ForegroundColor Cyan
Write-Host ""
