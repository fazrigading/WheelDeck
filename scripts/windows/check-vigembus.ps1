# WheelDeck Windows setup check — detects ViGEmBus presence and status.
# Does NOT auto-install (per ADR-0005). Offers to open the browser to the
# release page so the user can download and install it themselves.

$ErrorActionPreference = "SilentlyContinue"

function Pass($msg) { Write-Host "  OK  $msg" -ForegroundColor Green }
function Fail($msg) { Write-Host "  X   $msg" -ForegroundColor Red }
function Warn($msg) { Write-Host "  !   $msg" -ForegroundColor Yellow }

$issues = 0

Write-Host "WheelDeck ViGEmBus setup check"
Write-Host "=============================="
Write-Host

# 1. Check if ViGEmBus service exists
$service = Get-Service -Name "ViGEmBus" -ErrorAction SilentlyContinue
if ($service) {
    if ($service.Status -eq "Running") {
        Pass "ViGEmBus service is running"
    } else {
        Fail "ViGEmBus service exists but is not running (Status: $($service.Status))"
        $issues++
    }
} else {
    Fail "ViGEmBus service not found"
    $issues++
}

# 2. Check if ViGEmClient.dll is reachable
$dllFound = $false

# Check PATH
$dllInPath = Get-Command "ViGEmClient.dll" -ErrorAction SilentlyContinue
if ($dllInPath) {
    $dllFound = $true
}

# Check common install locations
$commonPaths = @(
    "${env:ProgramFiles}\ViGEm",
    "${env:ProgramFiles(x86)}\ViGEm",
    "${env:LOCALAPPDATA}\ViGEm"
)

foreach ($dir in $commonPaths) {
    $dllPath = Join-Path $dir "ViGEmClient.dll"
    if (Test-Path $dllPath) {
        $dllFound = $true
        break
    }
}

if ($dllFound) {
    Pass "ViGEmClient.dll found"
} else {
    Warn "ViGEmClient.dll not found in PATH or common locations"
}

# 3. Summary and remediation
Write-Host
Write-Host "=============================="
if ($issues -eq 0) {
    Write-Host "ViGEmBus is installed and ready for WheelDeck."
    exit 0
} else {
    Write-Host "$issues issue(s) found."
    Write-Host
    $answer = Read-Host "Open browser to ViGEmBus release page? (Y/n)"
    if ($answer -ne "n" -and $answer -ne "N") {
        Start-Process "https://github.com/ViGEm/ViGEmBus/releases"
        Write-Host
        Write-Host "Download the latest installer, run it, then re-run this script."
    } else {
        Write-Host "Download ViGEmBus from: https://github.com/ViGEm/ViGEmBus/releases"
    }
    exit 1
}
