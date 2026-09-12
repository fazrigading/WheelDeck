# Desktop developer guide

This guide gets you set up, building, testing, and contributing to the WheelDeck desktop server. It's a C#/.NET application with an Avalonia UI that receives WebSocket input from the phone and translates it into a virtual game controller on Windows (HIDMaestro) and Linux (uinput).

## Prerequisites

| Tool | Minimum |
|---|---|
| .NET SDK | 8.0+ |
| HIDMaestro (Windows) | n/a | Auto-installs on first use via `HMContext.InstallDriver()` (admin required) — see `https://github.com/hifihedgehog/HIDMaestro` |
| uinput (Linux) | Per distro (see below) |

## Get started

```bash
cd desktop
dotnet build
dotnet run --project WheelDeck.App
```

Or open `WheelDeck.sln` in an IDE (Visual Studio, VS Code, Rider).

## Project structure

See [`project-structure.md`](./project-structure.md) for the full repository layout.

## Build & run

| Goal | Command |
|---|---|
| Build the solution | `dotnet build` |
| Build a specific project | `dotnet build WheelDeck.App/WheelDeck.App.csproj` |
| Run the desktop server | `dotnet run --project WheelDeck.App` |
| Run with debug logging | `DOTNET_ENVIRONMENT=Development dotnet run --project WheelDeck.App` |

## Testing

```bash
# All tests
dotnet test

# Core unit tests (protocol, pairing, mapper)
dotnet test WheelDeck.Tests/WheelDeck.Tests.csproj

# Run a specific test
dotnet test --filter "FullyQualifiedName~PairingManager"

# Run with coverage
dotnet test --collect:"XPlat Code Coverage"
```

Test coverage targets (see [`plan/feature-wheeldeck-v1-1.md`](../plan/feature-wheeldeck-v1-1.md), TEST-001 through TEST-004):
- Protocol models serialize/deserialize matching schema constraints
- `PairingManager` expires devices after 30 days and revokes on demand
- `InputMapper` routes axes and buttons per mapping mode
- `neutralize()` zeroes axes and releases buttons on all four call sites

## Key concepts

### VirtualOutputBackend

The `VirtualOutputBackend` interface (defined in `WheelDeck.Core`) is the single abstraction for driving a virtual controller:

```csharp
interface VirtualOutputBackend {
    Result initialize();
    void setAxis(AxisType axis, float value);         // steering: -1..1, pedals: 0..1
    void setButton(ButtonId button, bool pressed);     // controller-button mapping mode
    void sendKey(KeyCode key, bool pressed);            // simulated-keypress mapping mode
    void neutralize();                                  // zero all axes, release all buttons/keys
    void shutdown();
}
```

The composition root (`WheelDeck.App/CompositionRoot.cs`) picks the implementation at startup based on the running OS: `WindowsBackend` on Windows, `LinuxBackend` on Linux.

### neutralize() call sites

`neutralize()` **must** be called on every termination path:

- **WebSocket disconnect**: phone dropped off the network
- **Heartbeat timeout**: 2 missed ~2s heartbeats from `HeartbeatMonitor`
- **Active device switch**: when `SessionGate` authorizes a different `PairedDevice`
- **Server shutdown**: `Program.cs` calls `shutdown()` on exit

See [ADR-0001](./adr/0001-neutralize-on-device-switch.md) for why this fires *before* the new device is authorized.

### PairingManager

Lives in `WheelDeck.Core/Pairing/`. Responsibilities:

- `generatePairingCode()`: creates a PIN or QR code for the phone
- `validatePairing(deviceId, code)`: verifies the entered/scanned value
- `listPairedDevices()`: returns all `PairedDevice` records
- `setActiveDevice(deviceId)`: switches active device and triggers `neutralize()`
- `revokeDevice(deviceId)`: removes a device
- `isExpired(device)`: true if `lastSeenAt > 30 days ago`
- `touchLastSeen(deviceId)`: called on every heartbeat

Persistence is abstracted behind `IPairingStore` (default: `JsonFilePairingStore`).

### Session gate

`WheelDeck.Core/Network/SessionGate.cs` enforces the single safety rule from the PRD: **no state or button message reaches the `InputMapper` unless it originates from the currently active, non-expired, non-revoked device.** This is the single point where the "public space, untrusted network" safety requirement is enforced. Do not duplicate this check elsewhere.

### InputMapper

`WheelDeck.Core/Input/InputMapper.cs` decides, per dashboard control, whether to call `setButton` (virtual-controller button mapping mode) or `sendKey` (simulated key presses, the default per the PRD). Your `MappingMode` setting drives that decision.

### WebSocketListener

`WheelDeck.Core/Network/WebSocketListener.cs` is the TCP listener that accepts WebSocket connections and routes messages:
- `state` messages → `InputMapper.setAxis()` (steering, accelerator, brake, clutch)
- `button` messages → `InputMapper` (mapped to `setButton` or `sendKey`)
- Session messages → `PairingService` (pairing, heartbeats, device switches)

### Setup check

`WheelDeck.App/SetupChecker.cs` runs on first launch:
- **Windows**: checks for the HIDMaestro driver. If missing, the app installs it automatically (requires administrator).
- **Linux**: checks uinput permissions. If missing, prints remediation commands.

Per [ADR-0004](./adr/0004-degraded-continue-setup-check.md), the check **does not block**. It shows instructions and continues in a degraded state. Pairing works without the output backend.

## Platform-specific setup

### Windows (HIDMaestro)

1. Run the app as administrator on first launch — the HIDMaestro driver installs automatically
2. The setup checker verifies the driver before the backend initializes
3. Or check status manually: `scripts/windows/check-hidmaestro.ps1`

HIDMaestro creates a virtual Xbox controller that simulators like ETS2 read natively (`joy.cpl` shows "Controller (XBOX 360 For Windows)" while the app is running). Key simulation uses the Win32 `SendInput` API.

### Linux (uinput)

1. Ensure the `uinput` kernel module is loaded:
   ```bash
   modprobe uinput
   ```
2. Configure udev permissions:
   ```bash
   scripts/linux/install-uinput-rules.sh
   ```
3. Follow any distro-specific remediation the script prints (SELinux on Fedora, udev rule install everywhere).

| Distro | Kernel module package | Notes |
|---|---|---|
| Fedora / RHEL (+Nobara) | `sudo dnf install kernel-modules-extra` | SELinux steps per script output |
| Ubuntu / Debian (+Mint, Pop!_OS, Zorin) | built-in, no package | AppArmor stock OK; install udev rule via script output |
| Arch (+Manjaro, EndeavourOS, Garuda) | built into `linux` / `linux-lts` kernel | same udev rule path |

The uinput backend creates a virtual joystick device. Key simulation uses uinput synthetic key events.

## Configuration

The desktop server launches manually by default. You open the app when you want to play. Running as a background daemon or service is an opt-in advanced setting, kept out of the main flow. That keeps friction low for typical use.

> Even in daemon mode, the server must require an active paired-and-connected phone before accepting any input, same as manual launch.

## First-run setup scripts

Located in `scripts/`:

| Script | Platform | Purpose |
|---|---|---|
| `scripts/windows/check-hidmaestro.ps1` | Windows | Detects HIDMaestro driver state; install is automatic via the app (admin) |
| `scripts/linux/install-uinput-rules.sh` | Linux | Detects uinput/SELinux issues, prints commands for you to run manually |

> **ADR-0005**: The Linux script is detect-only. On Windows, driver install is automatic via the app (admin required); `check-hidmaestro.ps1` is a status check.

## CI

`desktop/` has its own workflow at `../.github/workflows/desktop-ci.yml`. It builds on a .NET runner and includes platform-specific dependencies for backend tests. A mobile-only change does not trigger a full desktop build.

## Adding a new control or action

1. Add the enum value to `protocol/schema/controls.json`
2. Add the same value to `ControlId` in `WheelDeck.Core/Protocol/ControlId.cs`
3. Add the same value to the `ControlId` enum in `mobile/lib/data/services/dashboard_input.dart`
4. Map the control in `InputMapper.cs` (which `setButton` or `sendKey` line to use)

> The protocol schema is the single source of truth. Do not add control enums to code without adding them to the schema first.


