# Windows Optimizer - by souhaibahmed
# Usage: irm https://raw.githubusercontent.com/souhaibahmed/windows-optimizer/main/setup.ps1 | iex

$base = "https://raw.githubusercontent.com/souhaibahmed/windows-optimizer/main"

Clear-Host
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "         Windows Optimizer v1.0         " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  [1]  Backup Data" -ForegroundColor Yellow
Write-Host "  [2]  Start Optimizing Current Rig" -ForegroundColor Green
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

$choice = Read-Host "Enter your choice (1 or 2)"

switch ($choice) {
    "1" {
        Write-Host "`nLoading Backup module..." -ForegroundColor Yellow
        iex (irm "$base/backup.ps1")
    }
    "2" {
        Write-Host "`nLoading Optimizer module..." -ForegroundColor Green
        iex (irm "$base/optimize.ps1")
    }
    default {
        Write-Host "`nInvalid choice. Please run the script again." -ForegroundColor Red
    }
}
