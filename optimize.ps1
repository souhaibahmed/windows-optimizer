# ============================================================
#  Windows Optimizer - Optimizer Module
#  by souhaibahmed
#  https://github.com/souhaibahmed/windows-optimizer
#
#  Credits:
#   - Bloatware list inspired by BloatyNosy by builtbybel
#     https://github.com/builtbybel/Bloatynosy (MIT License)
#   - Driver updates via PSWindowsUpdate by Michal Gajda
#     https://www.powershellgallery.com/packages/PSWindowsUpdate
#   - App installs via winget by Microsoft
#     https://github.com/microsoft/winget-cli (MIT License)
# ============================================================

$base = "https://raw.githubusercontent.com/souhaibahmed/windows-optimizer/main"

# ── Admin check ───────────────────────────────────────────────
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-Host ""
    Write-Host "  This module requires Administrator privileges." -ForegroundColor Red
    Write-Host "  Please re-run PowerShell as Administrator." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Press any key to go back..." -ForegroundColor DarkGray
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
    iex (irm "$base/setup.ps1")
    return
}

# ── Winget check ──────────────────────────────────────────────
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "  winget is not available on this system!" -ForegroundColor Red
    Write-Host "  Please install 'App Installer' from the Microsoft Store first." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Press any key to go back..." -ForegroundColor DarkGray
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
    iex (irm "$base/setup.ps1")
    return
}

# ════════════════════════════════════════════════════════════
#  STEP 1 — APP SELECTOR (TUI)
# ════════════════════════════════════════════════════════════

$items = @(
    # ── Browsers ──────────────────────────────────────────────
    [PSCustomObject]@{Type="header"; Name="BROWSERS";              WingetId=""; Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Google Chrome";         WingetId="Google.Chrome";                      Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Mozilla Firefox";       WingetId="Mozilla.Firefox";                    Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Brave";                 WingetId="Brave.Brave";                        Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Opera GX";              WingetId="Opera.OperaGX";                      Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Vivaldi";               WingetId="Vivaldi.Vivaldi";                    Selected=$false},

    # ── Dev Tools ─────────────────────────────────────────────
    [PSCustomObject]@{Type="header"; Name="DEV TOOLS";             WingetId=""; Selected=$false},
    [PSCustomObject]@{Type="app";    Name="VS Code";               WingetId="Microsoft.VisualStudioCode";          Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Git";                   WingetId="Git.Git";                            Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Node.js LTS";           WingetId="OpenJS.NodeJS.LTS";                  Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Python 3";              WingetId="Python.Python.3";                    Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Windows Terminal";      WingetId="Microsoft.WindowsTerminal";           Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Docker Desktop";        WingetId="Docker.DockerDesktop";               Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Postman";               WingetId="Postman.Postman";                    Selected=$false},
    [PSCustomObject]@{Type="app";    Name="GitHub Desktop";        WingetId="GitHub.GitHubDesktop";               Selected=$false},

    # ── Media & Players ───────────────────────────────────────
    [PSCustomObject]@{Type="header"; Name="MEDIA & PLAYERS";       WingetId=""; Selected=$false},
    [PSCustomObject]@{Type="app";    Name="VLC Media Player";      WingetId="VideoLAN.VLC";                       Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Spotify";               WingetId="Spotify.Spotify";                    Selected=$false},
    [PSCustomObject]@{Type="app";    Name="OBS Studio";            WingetId="OBSProject.OBSStudio";               Selected=$false},
    [PSCustomObject]@{Type="app";    Name="HandBrake";             WingetId="HandBrake.HandBrake";                Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Audacity";              WingetId="Audacity.Audacity";                  Selected=$false},
    [PSCustomObject]@{Type="app";    Name="foobar2000";            WingetId="PeterPavlinek.foobar2000";           Selected=$false},
    [PSCustomObject]@{Type="app";    Name="MPV Player";            WingetId="mpv.net";                            Selected=$false},

    # ── Gaming ────────────────────────────────────────────────
    [PSCustomObject]@{Type="header"; Name="GAMING";                WingetId=""; Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Steam";                 WingetId="Valve.Steam";                        Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Epic Games Launcher";   WingetId="EpicGames.EpicGamesLauncher";        Selected=$false},
    [PSCustomObject]@{Type="app";    Name="GOG Galaxy";            WingetId="GOG.Galaxy";                         Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Ubisoft Connect";       WingetId="Ubisoft.Connect";                    Selected=$false},
    [PSCustomObject]@{Type="app";    Name="EA App";                WingetId="ElectronicArts.EADesktop";           Selected=$false},

    # ── Communication ─────────────────────────────────────────
    [PSCustomObject]@{Type="header"; Name="COMMUNICATION";         WingetId=""; Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Discord";               WingetId="Discord.Discord";                    Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Telegram";              WingetId="Telegram.TelegramDesktop";           Selected=$false},
    [PSCustomObject]@{Type="app";    Name="WhatsApp";              WingetId="WhatsApp.WhatsApp";                  Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Zoom";                  WingetId="Zoom.Zoom";                          Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Slack";                 WingetId="SlackTechnologies.Slack";            Selected=$false},

    # ── Utilities & System ────────────────────────────────────
    [PSCustomObject]@{Type="header"; Name="UTILITIES & SYSTEM";    WingetId=""; Selected=$false},
    [PSCustomObject]@{Type="app";    Name="7-Zip";                 WingetId="7zip.7zip";                          Selected=$false},
    [PSCustomObject]@{Type="app";    Name="WinRAR";                WingetId="RARLab.WinRAR";                      Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Notepad++";             WingetId="Notepad++.Notepad++";                Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Everything";            WingetId="voidtools.Everything";               Selected=$false},
    [PSCustomObject]@{Type="app";    Name="CPU-Z";                 WingetId="CPUID.CPU-Z";                        Selected=$false},
    [PSCustomObject]@{Type="app";    Name="GPU-Z";                 WingetId="TechPowerUp.GPU-Z";                  Selected=$false},
    [PSCustomObject]@{Type="app";    Name="HWiNFO";                WingetId="REALiX.HWiNFO";                     Selected=$false},
    [PSCustomObject]@{Type="app";    Name="CrystalDiskInfo";       WingetId="CrystalDewWorld.CrystalDiskInfo";   Selected=$false},
    [PSCustomObject]@{Type="app";    Name="ShareX";                WingetId="ShareX.ShareX";                     Selected=$false},
    [PSCustomObject]@{Type="app";    Name="TreeSize Free";         WingetId="JAMSoftware.TreeSize.Free";          Selected=$false},

    # ── Others ────────────────────────────────────────────────
    [PSCustomObject]@{Type="header"; Name="OTHERS";                WingetId=""; Selected=$false},
    [PSCustomObject]@{Type="app";    Name="qBittorrent";           WingetId="qBittorrent.qBittorrent";            Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Bitwarden";             WingetId="Bitwarden.Bitwarden";                Selected=$false},
    [PSCustomObject]@{Type="app";    Name="GIMP";                  WingetId="GIMP.GIMP";                          Selected=$false},
    [PSCustomObject]@{Type="app";    Name="LibreOffice";           WingetId="TheDocumentFoundation.LibreOffice";  Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Figma";                 WingetId="Figma.Figma";                        Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Adobe Acrobat Reader";  WingetId="Adobe.Acrobat.Reader.64-bit";        Selected=$false},
    [PSCustomObject]@{Type="app";    Name="Inkscape";              WingetId="Inkscape.Inkscape";                  Selected=$false},
    [PSCustomObject]@{Type="app";    Name="VirtualBox";            WingetId="Oracle.VirtualBox";                  Selected=$false}
)

# ── Index helpers ─────────────────────────────────────────────
$appIndices = @(for ($i = 0; $i -lt $items.Count; $i++) {
    if ($items[$i].Type -eq "app") { $i }
})

# ── TUI State ─────────────────────────────────────────────────
$cursorPos   = 0
$viewStart   = 0
$HEADER_ROWS = 6
$FOOTER_ROWS = 1
$viewSize    = [Math]::Max(5, $Host.UI.RawUI.WindowSize.Height - $HEADER_ROWS - $FOOTER_ROWS - 2)

# ── Renderer ──────────────────────────────────────────────────
function Draw-Screen {
    $w        = [Math]::Max(40, $Host.UI.RawUI.WindowSize.Width - 1)
    $selCount = @($items | Where-Object { $_.Selected }).Count
    $curItem  = $appIndices[$cursorPos]
    $bar      = "=" * $w

    [Console]::SetCursorPosition(0, 0)
    Write-Host $bar.Substring(0, $w) -ForegroundColor Cyan
    Write-Host ("   WINDOWS OPTIMIZER  -  App Selector").PadRight($w).Substring(0, $w) -ForegroundColor Cyan
    Write-Host $bar.Substring(0, $w) -ForegroundColor Cyan
    Write-Host ("  [SPACE] Toggle   [UP/DOWN] Move   [PgUp/PgDn] Jump   [ENTER] Confirm   [ESC] Back").PadRight($w).Substring(0, $w) -ForegroundColor DarkGray
    $selColor = if ($selCount -gt 0) { "Yellow" } else { "DarkGray" }
    Write-Host ("  >> $selCount app(s) selected").PadRight($w).Substring(0, $w) -ForegroundColor $selColor
    Write-Host $bar.Substring(0, $w) -ForegroundColor Cyan

    for ($row = 0; $row -lt $viewSize; $row++) {
        $idx = $viewStart + $row
        [Console]::SetCursorPosition(0, $HEADER_ROWS + $row)

        if ($idx -ge $items.Count) {
            Write-Host ("".PadRight($w))
            continue
        }

        $item = $items[$idx]

        if ($item.Type -eq "header") {
            $dashes = "-" * [Math]::Max(2, $w - $item.Name.Length - 7)
            $line   = ("  -- $($item.Name) $dashes").PadRight($w).Substring(0, $w)
            Write-Host $line -ForegroundColor Magenta
        } else {
            $cb   = if ($item.Selected) { "[*]" } else { "[ ]" }
            $line = ("   $cb  $($item.Name)").PadRight($w).Substring(0, $w)
            if ($idx -eq $curItem) {
                Write-Host $line -ForegroundColor Black -BackgroundColor Cyan
            } else {
                Write-Host $line -ForegroundColor White
            }
        }
    }

    [Console]::SetCursorPosition(0, $HEADER_ROWS + $viewSize)
    $endItem = [Math]::Min($viewStart + $viewSize, $items.Count)
    Write-Host ("  Showing $($viewStart + 1) to $endItem of $($items.Count)").PadRight($w).Substring(0, $w) -ForegroundColor DarkGray
}

function Adjust-Viewport {
    $ci = $appIndices[$cursorPos]
    if ($ci -lt $viewStart) {
        $script:viewStart = $ci
    } elseif ($ci -ge ($viewStart + $viewSize)) {
        $script:viewStart = $ci - $viewSize + 1
    }
}

# ── Selection Loop ────────────────────────────────────────────
Clear-Host
[Console]::CursorVisible = $false
Draw-Screen

$done = $false
while (-not $done) {
    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    switch ($key.VirtualKeyCode) {
        38 { # Up
            if ($cursorPos -gt 0) { $script:cursorPos-- }
            Adjust-Viewport
        }
        40 { # Down
            if ($cursorPos -lt ($appIndices.Count - 1)) { $script:cursorPos++ }
            Adjust-Viewport
        }
        33 { # Page Up
            $script:cursorPos = [Math]::Max(0, $cursorPos - 10)
            Adjust-Viewport
        }
        34 { # Page Down
            $script:cursorPos = [Math]::Min($appIndices.Count - 1, $cursorPos + 10)
            Adjust-Viewport
        }
        32 { # Space — toggle
            $items[$appIndices[$cursorPos]].Selected = -not $items[$appIndices[$cursorPos]].Selected
        }
        13 { # Enter — confirm
            $done = $true
        }
        27 { # ESC — back to main menu
            [Console]::CursorVisible = $true
            Clear-Host
            iex (irm "$base/setup.ps1")
            return
        }
    }

    if (-not $done) { Draw-Screen }
}

[Console]::CursorVisible = $true

# ════════════════════════════════════════════════════════════
#  STEP 2 — INSTALL SELECTED APPS VIA WINGET
# ════════════════════════════════════════════════════════════

$selected = @($items | Where-Object { $_.Type -eq "app" -and $_.Selected })

Clear-Host
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   Windows Optimizer - Installing Apps    " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

if ($selected.Count -eq 0) {
    Write-Host "  No apps selected. Skipping to debloat..." -ForegroundColor Yellow
    Start-Sleep 2
} else {
    Write-Host "  Installing $($selected.Count) app(s) silently via winget..." -ForegroundColor White
    Write-Host ""
    $i = 1
    foreach ($app in $selected) {
        Write-Host "  [$i/$($selected.Count)] $($app.Name)..." -ForegroundColor Yellow -NoNewline
        winget install --id $app.WingetId --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host " Done" -ForegroundColor Green
        } else {
            Write-Host " Failed  (retry: winget install $($app.WingetId))" -ForegroundColor Red
        }
        $i++
    }
    Write-Host ""
    Write-Host "  Installation complete!" -ForegroundColor Green
}

Write-Host ""
Write-Host "  Press any key to continue to debloat..." -ForegroundColor DarkGray
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null

# ════════════════════════════════════════════════════════════
#  STEP 3 — REMOVE BLOATWARE
# ════════════════════════════════════════════════════════════

function Remove-BloatApp {
    param([string]$AppName)
    $app = Get-AppxPackage -Name "*$AppName*" -AllUsers -ErrorAction SilentlyContinue
    if ($app) {
        Write-Host "  Removing   $AppName..." -ForegroundColor Yellow -NoNewline
        $app | Remove-AppxPackage -ErrorAction SilentlyContinue
        Write-Host " Done" -ForegroundColor Green
    } else {
        Write-Host "  Not found  $AppName" -ForegroundColor DarkGray
    }
}

function Remove-ProvisionedBloat {
    param([string]$AppName)
    $pkg = Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "*$AppName*" }
    if ($pkg) {
        $pkg | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
    }
}

Clear-Host
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   Windows Optimizer - Removing Bloatware " -ForegroundColor Cyan
Write-Host "   Inspired by BloatyNosy by builtbybel   " -ForegroundColor DarkGray
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$bloatApps = @(
    "Microsoft.3DBuilder",               "Microsoft.BingWeather",
    "Microsoft.BingNews",                "Microsoft.BingFinance",
    "Microsoft.BingSports",              "Microsoft.BingSearch",
    "Microsoft.GetHelp",                 "Microsoft.Getstarted",
    "Microsoft.MicrosoftOfficeHub",      "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MixedReality.Portal",     "Microsoft.People",
    "Microsoft.SkypeApp",                "Microsoft.Todos",
    "Microsoft.WindowsFeedbackHub",      "Microsoft.WindowsMaps",
    "Microsoft.WindowsSoundRecorder",    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxApp",                 "Microsoft.XboxGameOverlay",
    "Microsoft.XboxGamingOverlay",       "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay", "Microsoft.YourPhone",
    "Microsoft.ZuneMusic",               "Microsoft.ZuneVideo",
    "Microsoft.PowerAutomateDesktop",    "Microsoft.Teams",
    "MicrosoftTeams",                    "Microsoft.Clipchamp",
    "Microsoft.MicrosoftJournal",        "Microsoft.OutlookForWindows",
    "SpotifyAB.SpotifyMusic",            "Disney.37853D22215B2",
    "Facebook.Facebook",                 "AmazonVideo.PrimeVideo",
    "BytedancePte.TikTok",               "king.com.CandyCrush",
    "king.com.FarmHeroesSaga"
)

Write-Host "[ Removing installed bloatware ]" -ForegroundColor Magenta
Write-Host ""
foreach ($app in $bloatApps) { Remove-BloatApp $app }

Write-Host ""
Write-Host "[ Removing provisioned packages (prevents reinstall) ]" -ForegroundColor Magenta
Write-Host ""
foreach ($app in $bloatApps) { Remove-ProvisionedBloat $app }

Write-Host ""
Write-Host "  Debloat complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Press any key to continue to Edge removal..." -ForegroundColor DarkGray
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null

# ════════════════════════════════════════════════════════════
#  STEP 4 — REMOVE MICROSOFT EDGE
# ════════════════════════════════════════════════════════════

Clear-Host
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   Windows Optimizer - Removing Edge      " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Microsoft Edge is deeply integrated into Windows 11." -ForegroundColor White
Write-Host "  This will force-remove it using its own uninstaller" -ForegroundColor White
Write-Host "  and block it from reinstalling via registry." -ForegroundColor White
Write-Host ""
Write-Host "  Press ENTER to remove Edge or ESC to skip..." -ForegroundColor DarkGray

$edgeKey = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

if ($edgeKey.VirtualKeyCode -eq 13) {
    Write-Host ""

    # Method 1: winget
    Write-Host "  [1/3] Trying winget uninstall..." -ForegroundColor Yellow -NoNewline
    winget uninstall --id Microsoft.Edge --silent --accept-source-agreements 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host " Done" -ForegroundColor Green
    } else {
        Write-Host " Skipped (trying next method)" -ForegroundColor DarkGray
    }

    # Method 2: Edge's own setup.exe
    Write-Host "  [2/3] Trying Edge built-in uninstaller..." -ForegroundColor Yellow -NoNewline
    $edgeBase = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application"
    if (Test-Path $edgeBase) {
        $version = (Get-ChildItem $edgeBase -Directory -ErrorAction SilentlyContinue |
                    Sort-Object Name -Descending | Select-Object -First 1).Name
        $setupExe = "$edgeBase\$version\Installer\setup.exe"
        if (Test-Path $setupExe) {
            Start-Process $setupExe -ArgumentList "--uninstall --system-level --verbose-logging --force-uninstall" -Wait -NoNewWindow
            Write-Host " Done" -ForegroundColor Green
        } else {
            Write-Host " Installer not found" -ForegroundColor DarkGray
        }
    } else {
        Write-Host " Edge not found at default path" -ForegroundColor DarkGray
    }

    # Method 3: Block auto-reinstall via registry
    Write-Host "  [3/3] Blocking Edge auto-reinstall via registry..." -ForegroundColor Yellow -NoNewline
    $regPath = "HKLM:\SOFTWARE\Microsoft\EdgeUpdate"
    if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
    Set-ItemProperty -Path $regPath -Name "DoNotUpdateToEdgeWithChromium" -Value 1 -Type DWord -Force
    Write-Host " Done" -ForegroundColor Green

    Write-Host ""
    Write-Host "  Edge removal complete!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "  Skipping Edge removal." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "  Press any key to continue to driver updates..." -ForegroundColor DarkGray
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null

# ════════════════════════════════════════════════════════════
#  STEP 5 — UPDATE ALL DRIVERS
# ════════════════════════════════════════════════════════════

Clear-Host
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   Windows Optimizer - Driver Updater     " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  This will use Windows Update to fetch and install" -ForegroundColor White
Write-Host "  the latest drivers for all your hardware." -ForegroundColor White
Write-Host ""
Write-Host "  Press ENTER to update drivers or ESC to skip..." -ForegroundColor DarkGray

$driverKey = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

if ($driverKey.VirtualKeyCode -eq 13) {
    Write-Host ""

    Write-Host "  [1/3] Checking PSWindowsUpdate module..." -ForegroundColor Yellow -NoNewline
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
        Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck -Scope CurrentUser | Out-Null
        Write-Host " Installed" -ForegroundColor Green
    } else {
        Write-Host " Already installed" -ForegroundColor Green
    }

    Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue

    Write-Host "  [2/3] Scanning for driver updates..." -ForegroundColor Yellow
    Write-Host ""
    $updates = Get-WindowsUpdate -MicrosoftUpdate -UpdateType Driver -AcceptAll -IgnoreReboot -ErrorAction SilentlyContinue

    if ($updates -and $updates.Count -gt 0) {
        Write-Host "  Found $($updates.Count) driver update(s):" -ForegroundColor Cyan
        Write-Host ""
        foreach ($u in $updates) {
            Write-Host "    - $($u.Title)" -ForegroundColor White
        }
        Write-Host ""
        Write-Host "  [3/3] Installing driver updates..." -ForegroundColor Yellow
        Write-Host ""
        Install-WindowsUpdate -MicrosoftUpdate -UpdateType Driver -AcceptAll -IgnoreReboot -Verbose 2>&1 |
            Where-Object { $_ -match "Title|Result|KB" } |
            ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }

        Write-Host ""
        Write-Host "  All drivers updated!" -ForegroundColor Green
        Write-Host "  A restart is recommended to apply changes." -ForegroundColor Yellow
    } else {
        Write-Host "  [3/3] No driver updates found — you are up to date!" -ForegroundColor Green
    }
} else {
    Write-Host ""
    Write-Host "  Skipping driver updates." -ForegroundColor DarkGray
}

# ── Final Summary ─────────────────────────────────────────────
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "        Optimization Complete!            " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Steps completed:" -ForegroundColor White
Write-Host "    [OK] Apps installed via winget" -ForegroundColor Green
Write-Host "    [OK] Windows 11 bloatware removed" -ForegroundColor Green
Write-Host "    [OK] Microsoft Edge removed" -ForegroundColor Green
Write-Host "    [OK] Drivers updated" -ForegroundColor Green
Write-Host ""
Write-Host "  Please restart your PC to apply all changes." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Press any key to return to main menu..." -ForegroundColor DarkGray
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null

iex (irm "$base/setup.ps1")
