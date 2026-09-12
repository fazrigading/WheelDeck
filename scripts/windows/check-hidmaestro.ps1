# WheelDeck Windows setup check — reports HIDMaestro driver status.
# Install itself is automatic via the app (HMContext.InstallDriver(), admin
# required); this script only checks state and points at remediation.

$ErrorActionPreference = "SilentlyContinue"

function Pass($msg) { Write-Host "  OK  $msg" -ForegroundColor Green }
function Fail($msg) { Write-Host "  X   $msg" -ForegroundColor Red }
function Warn($msg) { Write-Host "  !   $msg" -ForegroundColor Yellow }

$issues = 0

Write-Host "WheelDeck HIDMaestro setup check"
Write-Host "================================="
Write-Host

# 1. Check if the HIDMaestro driver package is in the driver store
$driver = pnputil /enum-drivers 2>$null | Select-String "hidmaestro.inf" -Quiet
if ($driver) {
    Pass "HIDMaestro driver package (hidmaestro.inf) is in the driver store"
} else {
    Fail "HIDMaestro driver package not found in the driver store"
    $issues++
}

# 2. Check for live HIDMaestro virtual devices
$devices = Get-PnpDevice -FriendlyName "*HIDMaestro*" -ErrorAction SilentlyContinue
if ($devices) {
    Pass "HIDMaestro virtual device(s) present"
} else {
    Warn "No live HIDMaestro virtual devices (expected when the app is not running)"
}

# 3. Check if the vendored SDK DLL is present next to this checkout
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..") -ErrorAction SilentlyContinue
if ($repoRoot) {
    $dllPath = Join-Path $repoRoot "desktop\third_party\HIDMaestro\HIDMaestro.Core.dll"
    if (Test-Path $dllPath) {
        Pass "HIDMaestro.Core.dll vendored SDK found"
    } else {
        Warn "HIDMaestro.Core.dll not found under desktop\third_party\HIDMaestro\"
    }
}

# 4. Summary and remediation
Write-Host
Write-Host "================================="
if ($issues -eq 0) {
    Write-Host "HIDMaestro driver is installed and ready for WheelDeck."
    Write-Host "Note: creating a controller still requires running the app as administrator."
    exit 0
} else {
    Write-Host "$issues issue(s) found."
    Write-Host
    Write-Host "Run WheelDeck as administrator once — the app installs the driver automatically."
    Write-Host "Details: https://github.com/hifihedgehog/HIDMaestro"
    exit 1
}
