# Desktop developer guide

This guide gets you set up, building, testing, and contributing to the WheelDeck desktop server. It's a C#/.NET application with an Avalonia UI that receives WebSocket input from the phone and translates it into a virtual game controller on Windows (ViGEmBus) and Linux (uinput).

> **Terminology**: All component names, interface names, and message types below use the exact vocabulary from [`CONTEXT.md`](../CONTEXT.md). Folder names match the spec terminology.

## Prerequisites

| Tool | Minimum | Install |
|---|---|---|
| .NET SDK | 8.0+ | `https://dotnet.microsoft.com/download` |
| Avalonia templates | n/a | `dotnet tool install -g AvaloniaCli` |
| ViGEmBus (Windows) | n/a | `https://github.com/ViGEm/ViGEm.NET` |
| uinput (Linux) | n/a | System uinput (Fedora: `sudo dnf install kernel-modules-extra`) |

## Get started

```bash
cd desktop
dotnet build
dotnet run --project WheelDeck.App
```

Or open `WheelDeck.sln` in an IDE (Visual Studio, VS Code, Rider).

## Project structure

```
desktop/
├── WheelDeck.sln                        # Solution file
├── WheelDeck.App/                       # Avalonia UI + composition root
│   ├── App.axaml / App.axaml.cs         # App entry point
│   ├── Program.cs                       # Native host setup
│   ├── CompositionRoot.cs               # Picks the right VirtualOutputBackend by OS
│   ├── MainWindow.cs                    # Main window
│   ├── SetupChecker.cs                  # First-run ViGEmBus/uinput check
│   ├── Views/                           # XAML views (connection, pairing, status)
│   └── ViewModels/                      # ViewModels for each view
├── WheelDeck.Core/                      # Business logic (no OS dependencies)
│   ├── Protocol/                        # Message models generated from schema
│   │   ├── StateMessage.cs
│   │   ├── ButtonMessage.cs
│   │   ├── ControlId.cs
│   │   ├── ActionType.cs
│   │   ├── SessionMessages.cs
│   │   └── SnakeCaseEnumConverter.cs
│   ├── Pairing/
│   │   ├── PairingManager.cs           # Pairing logic (generate, validate, revoke, expire)
│   │   ├── IPairingStore.cs            # Interface for persistence
│   │   ├── JsonFilePairingStore.cs     # File-based persistence
│   │   ├── PairedDevice.cs
│   │   ├── PairingCode.cs
│   │   └── PairingResult.cs
│   ├── Input/
│   │   ├── InputMapper.cs              # Routes axes/buttons per mapping mode
│   │   └── MappingMode.cs
│   └── Network/
│       ├── WebSocketListener.cs         # TCP listener + WebSocket handling
│       ├── PairingService.cs            # Session-level pairing enforcement
│       ├── SessionGate.cs              # The active/non-expired/non-revoked gate
│       └── HeartbeatMonitor.cs         # 2s heartbeat, neutralizes on timeout
├── WheelDeck.Backends/
│   ├── Windows/                        # ViGEmBus implementation (ViGEm.NET)
│   │   ├── WindowsBackend.cs           # VirtualOutputBackend impl via ViGEmBus
│   │   └── SendInputKeySender.cs       # Simulated keypresses
│   └── Linux/                          # uinput implementation
│       └── LinuxBackend.cs             # VirtualOutputBackend impl via uinput
└── WheelDeck.Tests/                     # Unit tests
```

> **PAT-001**: Backends are split per platform (Windows/, Linux/) behind one interface. `WheelDeck.Core` depends only on the `VirtualOutputBackend` interface, never on a specific backend. Adding macOS later is a new folder, not a rewrite.

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
- **Windows**: checks for ViGEmBus driver. If missing, launches the browser to the official release page.
- **Linux**: checks uinput permissions. If missing, prints remediation commands.

Per [ADR-0004](./adr/0004-degraded-continue-setup-check.md), the check **does not block**. It shows instructions and continues in a degraded state. Pairing works without the output backend.

## Platform-specific setup

### Windows (ViGEmBus)

1. Download and install ViGEmBus from `https://github.com/ViGEm/ViGEm.NET/releases`
2. Run the setup checker: the app prompts you if it's missing
3. Or run manually: `scripts/windows/check-vigembus.ps1`

ViGEmBus creates a virtual Xbox controller that simulators like ETS2 read natively. Key simulation uses the Win32 `SendInput` API.

### Linux (uinput)

1. Ensure the `uinput` kernel module is loaded:
   ```bash
   modprobe uinput
   ```
2. Configure udev permissions:
   ```bash
   scripts/linux/install-uinput-rules.sh
   ```
3. On Fedora with SELinux, follow the additional remediation steps the script prints.

The uinput backend creates a virtual joystick device. Key simulation uses uinput synthetic key events.

## Configuration

The desktop server launches manually by default. You open the app when you want to play. Running as a background daemon or service is an opt-in advanced setting, kept out of the main flow. That keeps friction low for typical use.

> Even in daemon mode, the server must require an active paired-and-connected phone before accepting any input, same as manual launch.

## First-run setup scripts

Located in `scripts/`:

| Script | Platform | Purpose |
|---|---|---|
| `scripts/windows/check-vigembus.ps1` | Windows | Detects ViGEmBus, offers to launch the browser to the official release page |
| `scripts/linux/install-uinput-rules.sh` | Linux | Detects uinput/SELinux issues, prints commands for you to run manually |

> **ADR-0005**: These scripts detect-only. They do not install drivers or modify permissions directly. They show you what is missing and either launch a browser (Windows) or print commands to run manually (Linux).

## CI

`desktop/` has its own workflow at `../.github/workflows/desktop-ci.yml`. It builds on a .NET runner and includes platform-specific dependencies for backend tests. A mobile-only change does not trigger a full desktop build.

## Adding a new control or action

1. Add the enum value to `protocol/schema/controls.json`
2. Add the same value to `ControlId` in `WheelDeck.Core/Protocol/ControlId.cs`
3. Add the same value to the `ControlId` enum in `mobile/lib/input/dashboard_input.dart`
4. Map the control in `InputMapper.cs` (which `setButton` or `sendKey` line to use)

> The protocol schema is the single source of truth. Do not add control enums to code without adding them to the schema first.

## Useful references

- [`backend-interface.md`](./backend-interface.md): Full specification of the wire protocol, PairingManager interface, VirtualOutputBackend interface, and neutralize() call sites
- [`CONTEXT.md`](../CONTEXT.md): Domain glossary and terminology
- [`project-structure.md`](./project-structure.md): Repository layout rationale
- [`prd.md`](./prd.md#desktop-server): Desktop feature list and requirements
- [`../plan/feature-wheeldeck-v1-1.md`](../plan/feature-wheeldeck-v1-1.md): Implementation tasks (TASK-009 through TASK-025 for desktop)
- [`../docs/adr/`](../docs/adr/): Architecture decisions (especially ADR-0001 for neutralize-on-switch, ADR-0004 for degraded setup check)
- [`mobile-dev-guide.md`](./mobile-dev-guide.md): The mobile counterpart of this guide
