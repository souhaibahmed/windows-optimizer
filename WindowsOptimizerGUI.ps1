Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "SilentlyContinue"

function Get-SystemInfo {
    $os = Get-CimInstance Win32_OperatingSystem
    $build = [int]$os.BuildNumber
    if ($build -ge 22000) { $version = "Windows 11" } else { $version = "Windows 10" }
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
    $ram = [math]::Round($os.TotalVisibleMemorySize / 1MB)
    $wingetAvailable = $false
    try { if ((winget --version 2>$null) -or (Get-Command winget -ErrorAction SilentlyContinue)) { $wingetAvailable = $true } } catch {}
    return @{
        WinVersion = $version
        BuildNumber = $build
        GpuName = $gpu.Name
        RamGB = $ram
        WingetAvailable = $wingetAvailable
    }
}

function Set-Reg($Path, $Name, $Value, $Type = "DWord") {
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction SilentlyContinue
}

function Disable-Svc($Name) {
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($svc) {
        if ($svc.Status -eq "Running") { Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue }
        Set-Service -Name $Name -StartupType Disabled -ErrorAction SilentlyContinue
    }
}

function Run-Task($label, $scriptBlock) {
    $LogBox.AppendText("[>>] $label...`r`n")
    $LogBox.Refresh()
    try { & $scriptBlock } catch {}
    $LogBox.AppendText("[+] Done`r`n")
    $LogBox.Refresh()
}

$Session = Get-SystemInfo

$MainForm = New-Object System.Windows.Forms.Form
$MainForm.Text = "Windows Optimizer v2.0"
$MainForm.Size = New-Object System.Drawing.Size(900, 700)
$MainForm.StartPosition = "CenterScreen"
$MainForm.FormBorderStyle = "FixedDialog"
$MainForm.MaximizeBox = $false
$MainForm.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)

$topPanel = New-Object System.Windows.Forms.Panel
$topPanel.Dock = "Top"
$topPanel.Height = 80
$topPanel.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
$MainForm.Controls.Add($topPanel)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Windows Optimizer"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = "White"
$titleLabel.AutoSize = $true
$titleLabel.Location = New-Object System.Drawing.Point(20, 20)
$topPanel.Controls.Add($titleLabel)

$versionLabel = New-Object System.Windows.Forms.Label
$versionLabel.Text = "v2.0 by souhaibahmed"
$versionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$versionLabel.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
$versionLabel.AutoSize = $true
$versionLabel.Location = New-Object System.Drawing.Point(22, 52)
$topPanel.Controls.Add($versionLabel)

$sysInfoLabel = New-Object System.Windows.Forms.Label
$sysInfoLabel.Text = "$($Session.WinVersion) | $($Session.GpuName) | $($Session.RamGB) GB RAM"
$sysInfoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$sysInfoLabel.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$sysInfoLabel.TextAlign = "TopRight"
$sysInfoLabel.AutoSize = $true
$sysInfoLabel.Location = New-Object System.Drawing.Point(620, 20)
$topPanel.Controls.Add($sysInfoLabel)

$leftPanel = New-Object System.Windows.Forms.Panel
$leftPanel.Dock = "Left"
$leftPanel.Width = 280
$leftPanel.BackColor = [System.Drawing.Color]::FromArgb(25, 25, 25)
$MainForm.Controls.Add($leftPanel)

$modulesLabel = New-Object System.Windows.Forms.Label
$modulesLabel.Text = "OPTIMIZATION MODULES"
$modulesLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$modulesLabel.ForeColor = [System.Drawing.Color]::FromArgb(150, 150, 150)
$modulesLabel.Location = New-Object System.Drawing.Point(15, 15)
$modulesLabel.AutoSize = $true
$leftPanel.Controls.Add($modulesLabel)

$checkboxes = @{}

function Create-Checkbox($text, $y, $tag) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $text
    $cb.AutoSize = $true
    $cb.Location = New-Object System.Drawing.Point(15, $y)
    $cb.ForeColor = [System.Drawing.Color]::FromArgb(220, 220, 220)
    $cb.BackColor = [System.Drawing.Color]::Transparent
    $cb.FlatStyle = "Flat"
    $cb.Tag = $tag
    return $cb
}

$modules = @(
    @{Name="Performance Tweaks"; Tag="perf"},
    @{Name="Privacy & Telemetry"; Tag="privacy"},
    @{Name="Debloat Windows"; Tag="debloat"},
    @{Name="Gaming Optimizations"; Tag="gaming"},
    @{Name="System Cleanup"; Tag="cleanup"},
    @{Name="Windows Update Settings"; Tag="update"}
)

$y = 45
foreach ($mod in $modules) {
    $cb = Create-Checkbox $mod.Name $y $mod.Tag
    $checkboxes[$mod.Tag] = $cb
    $leftPanel.Controls.Add($cb)
    $y += 35
}

$appsCheck = Create-Checkbox "Install Essential Apps" $y "apps"
$checkboxes["apps"] = $appsCheck
$leftPanel.Controls.Add($appsCheck)
$y += 35

$selectAllBtn = New-Object System.Windows.Forms.Button
$selectAllBtn.Text = "Select All"
$selectAllBtn.Size = New-Object System.Drawing.Size(120, 30)
$selectAllBtn.Location = New-Object System.Drawing.Point(15, $y + 10)
$selectAllBtn.FlatStyle = "Flat"
$selectAllBtn.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
$selectAllBtn.ForeColor = "White"
$selectAllBtn.Add_Click({
    foreach ($cb in $checkboxes.Values) { $cb.Checked = $true }
})
$leftPanel.Controls.Add($selectAllBtn)

$deselectAllBtn = New-Object System.Windows.Forms.Button
$deselectAllBtn.Text = "Deselect All"
$deselectAllBtn.Size = New-Object System.Drawing.Size(120, 30)
$deselectAllBtn.Location = New-Object System.Drawing.Point(145, $y + 10)
$deselectAllBtn.FlatStyle = "Flat"
$deselectAllBtn.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
$deselectAllBtn.ForeColor = "White"
$deselectAllBtn.Add_Click({
    foreach ($cb in $checkboxes.Values) { $cb.Checked = $false }
})
$leftPanel.Controls.Add($deselectAllBtn)

$rightPanel = New-Object System.Windows.Forms.Panel
$rightPanel.Dock = "Fill"
$rightPanel.Padding = New-Object System.Windows.Forms.Padding(15)
$rightPanel.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
$MainForm.Controls.Add($rightPanel)

$LogBox = New-Object System.Windows.Forms.TextBox
$LogBox.Dock = "Fill"
$LogBox.Multiline = $true
$LogBox.ReadOnly = $true
$LogBox.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 20)
$LogBox.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
$LogBox.Font = New-Object System.Drawing.Font("Consolas", 10)
$LogBox.ScrollBars = "Vertical"
$LogBox.BorderStyle = "None"
$LogBox.Text = "Ready. Select modules and click 'Start Optimization' to begin.`r`n`r'n"
$rightPanel.Controls.Add($LogBox)

$bottomPanel = New-Object System.Windows.Forms.Panel
$bottomPanel.Dock = "Bottom"
$bottomPanel.Height = 60
$bottomPanel.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 20)
$MainForm.Controls.Add($bottomPanel)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Size = New-Object System.Drawing.Size(400, 20)
$progressBar.Location = New-Object System.Drawing.Point(20, 20)
$progressBar.Style = "Continuous"
$progressBar.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
$progressBar.ForeColor = [System.Drawing.Color]::FromArgb(0, 180, 100)
$bottomPanel.Controls.Add($progressBar)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Ready"
$statusLabel.Location = New-Object System.Drawing.Point(430, 22)
$statusLabel.AutoSize = $true
$statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(150, 150, 150)
$bottomPanel.Controls.Add($statusLabel)

$startBtn = New-Object System.Windows.Forms.Button
$startBtn.Text = "Start Optimization"
$startBtn.Size = New-Object System.Drawing.Size(160, 40)
$startBtn.Location = New-Object System.Drawing.Point(660, 10)
$startBtn.FlatStyle = "Flat"
$startBtn.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 60)
$startBtn.ForeColor = "White"
$startBtn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$startBtn.Add_Click({
    $selected = @()
    foreach ($key in $checkboxes.Keys) {
        if ($checkboxes[$key].Checked) { $selected += $key }
    }

    if ($selected.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one module.", "Windows Optimizer", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $LogBox.Clear()
    $startBtn.Enabled = $false
    $progressBar.Value = 0
    $progressBar.Maximum = $selected.Count * 100

    $tasks = @{
        perf = {
            Run-Task "Activating High Performance power plan" {
                $hp = powercfg -list | Select-String "High performance"
                if ($hp) { $guid = ($hp -split '\s+')[3]; powercfg -setactive $guid }
            }
            Run-Task "Minimizing visual effects" {
                Set-Reg "HKCU:\Control Panel\Desktop" "VisualFXSetting" 2
                Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" 0
            }
            Run-Task "Disabling SysMain/Superfetch" { Disable-Svc "SysMain" }
            Run-Task "Disabling Hibernation" { powercfg -h off }
            Run-Task "Disabling NTFS last access" { fsutil behavior set disableLastAccess 1 }
            Run-Task "Removing network throttling" {
                Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 0xFFFFFFFF
            }
        }
        privacy = {
            Run-Task "Disabling telemetry" {
                Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 0
                Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
            }
            Run-Task "Disabling DiagTrack" { Disable-Svc "DiagTrack" }
            Run-Task "Disabling WerSvc" { Disable-Svc "WerSvc" }
            Run-Task "Disabling Advertising ID" {
                Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0
            }
            Run-Task "Disabling Activity History" {
                Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "PublishUserActivities" 0
            }
            Run-Task "Disabling Cortana" {
                Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortana" 0
            }
        }
        debloat = {
            Run-Task "Removing UWP apps" {
                $apps = @("Microsoft.3DBuilder","Microsoft.BingFinance","Microsoft.BingNews","Microsoft.BingSports","Microsoft.BingWeather","Microsoft.Getstarted","Microsoft.GetHelp","Microsoft.Messaging","Microsoft.OfficeHub","Microsoft.MicrosoftSolitaireCollection","Microsoft.People","Microsoft.SkypeApp","Microsoft.Todos","Microsoft.XboxApp","Microsoft.XboxGameOverlay","Microsoft.YourPhone","Microsoft.ZuneMusic","Microsoft.ZuneVideo","DisneyPlus","SpotifyMusic","CandyCrush","Facebook")
                foreach ($app in $apps) {
                    Get-AppxPackage -AllUsers $app -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                }
            }
            Run-Task "Removing OneDrive" {
                Stop-Process -Name OneDriveSetup -Force -ErrorAction SilentlyContinue
                $ond = "$env:SystemRoot\System32\OneDriveSetup.exe"
                if (Test-Path $ond) { Start-Process $ond "/uninstall" -WindowStyle Hidden -Wait }
            }
            Run-Task "Blocking auto-reinstall" {
                Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SilentInstalledAppsEnabled" 0
                Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "ContentDeliveryAllowed" 0
            }
        }
        gaming = {
            Run-Task "Enabling Game Mode" {
                Set-Reg "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode" 1
                Set-Reg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1
            }
            Run-Task "Disabling Xbox Game DVR" {
                Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
                Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "GameDVR_Enabled" 0
            }
            if ($Session.BuildNumber -ge 19041) {
                Run-Task "Enabling HAGS" {
                    Set-Reg "HKLM:\System\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 2
                }
            }
            Run-Task "Disabling mouse acceleration" {
                Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "0"
                Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" "0"
                Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" "0"
            }
            Run-Task "Disabling Xbox services" {
                Disable-Svc "XblAuthManager"; Disable-Svc "XblGameSave"
                Disable-Svc "XboxNetApiSvc"; Disable-Svc "XboxGipSvc"
            }
        }
        cleanup = {
            Run-Task "Clearing User Temp" {
                if (Test-Path $env:TEMP) { Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue }
            }
            Run-Task "Clearing System Temp" {
                $sysTemp = "$env:SystemRoot\Temp"
                if (Test-Path $sysTemp) { Remove-Item "$sysTemp\*" -Recurse -Force -ErrorAction SilentlyContinue }
            }
            Run-Task "Flushing DNS" { ipconfig /flushdns | Out-Null }
            Run-Task "Emptying Recycle Bin" { Clear-RecycleBin -Force -ErrorAction SilentlyContinue }
        }
        update = {
            Run-Task "Disabling auto-updates" {
                Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoUpdate" 1
                Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "AUOptions" 2
            }
            Run-Task "Deferring feature updates (365d)" {
                Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "DeferFeatureUpdates" 1
                Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "DeferFeatureUpdatesPeriodInDays" 365
            }
            Run-Task "Deferring quality updates (30d)" {
                Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "DeferQualityUpdates" 1
                Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "DeferQualityUpdatesPeriodInDays" 30
            }
            Run-Task "Blocking driver updates" {
                Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "ExcludeWUDriversInQualityUpdate" 1
            }
        }
        apps = {
            if ($Session.WingetAvailable) {
                Run-Task "Checking winget availability" { }
                $LogBox.AppendText("[!] Use console version to install apps with winget`r`n")
            } else {
                $LogBox.AppendText("[!] winget not available on this system`r`n")
            }
        }
    }

    $i = 0
    foreach ($tag in $selected) {
        $LogBox.AppendText("`r`n=== $($checkboxes[$tag].Text.ToUpper()) ===`r`n")
        if ($tasks[$tag]) {
            & $tasks[$tag]
        }
        $i++
        $progressBar.Value = $i * 100
        $statusLabel.Text = "Completed: $($checkboxes[$tag].Text)"
        $statusLabel.Refresh()
    }

    $progressBar.Value = $progressBar.Maximum
    $statusLabel.Text = "Complete"
    $LogBox.AppendText("`r`n========================================`r`n")
    $LogBox.AppendText("[+] Optimization complete!`r`n")
    $LogBox.AppendText("[!] Restart your PC for full effect.`r`n")

    $startBtn.Enabled = $true
    [System.Windows.Forms.MessageBox]::Show("Optimization complete! Please restart your PC.", "Windows Optimizer", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

$bottomPanel.Controls.Add($startBtn)

$exitBtn = New-Object System.Windows.Forms.Button
$exitBtn.Text = "Exit"
$exitBtn.Size = New-Object System.Drawing.Size(80, 40)
$exitBtn.Location = New-Object System.Drawing.Point(740, 10)
$exitBtn.FlatStyle = "Flat"
$exitBtn.BackColor = [System.Drawing.Color]::FromArgb(180, 50, 50)
$exitBtn.ForeColor = "White"
$exitBtn.Add_Click({ $MainForm.Close() })
$bottomPanel.Controls.Add($exitBtn)

[void]$MainForm.ShowDialog()
