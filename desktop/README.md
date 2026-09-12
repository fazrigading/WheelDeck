# WheelDeck Desktop

C#/.NET 10 desktop server that receives WebSocket input from the phone app and translates it into a virtual game controller. Uses Avalonia UI for the GUI.

## Overview

Runs on Windows (HIDMaestro virtual Xbox controller) or Linux (uinput virtual joystick). Pairing, session management, and input routing are handled in `WheelDeck.Core` with zero platform dependencies. The composition root picks the right backend at startup.

Two run modes:
- **GUI** (default) — `dotnet run --project WheelDeck.App`
- **Daemon** (headless) — `dotnet run --project WheelDeck.App --daemon`

## Architecture

```
desktop/
├── WheelDeck.sln                      # Solution file
├── WheelDeck.App/                     # Avalonia UI + composition root
│   ├── Program.cs                     # Entry point (GUI or --daemon)
│   ├── CompositionRoot.cs             # DI, picks VirtualOutputBackend by OS
│   ├── SetupChecker.cs                # First-run HIDMaestro/uinput check
│   ├── Views/                         # XAML views (connection, pairing, status)
│   └── ViewModels/                    # MVVM view models
├── WheelDeck.Core/                    # Domain logic (no OS dependencies)
│   ├── Protocol/                      # Message models from protocol/schema/
│   ├── Pairing/                       # PairingManager, IPairingStore, session tokens
│   ├── Input/                         # InputMapper, MappingMode
│   └── Network/                       # WebSocketListener, PairingService, SessionGate, HeartbeatMonitor
├── WheelDeck.Backends/
│   ├── Windows/                       # HIDMaestro virtual Xbox 360 controller
│   │   ├── HidMaestroBackend.cs
│   │   └── SendInputKeySimulator.cs   # Win32 SendInput for key simulation
│   └── Linux/                         # uinput virtual joystick
│       └── UinputBackend.cs
└── WheelDeck.Tests/                   # xunit unit tests
```

## Prerequisites

| Tool | Minimum |
|------|---------|
| .NET SDK | 10.0+ |
| HIDMaestro driver | Windows only — auto-installs on first run (admin required), see [HIDMaestro](https://github.com/hifihedgehog/HIDMaestro) |
| uinput | Linux only — per distro (see below) |

## Guide

See [`docs/desktop-dev-guide.md`](../docs/desktop-dev-guide.md) for setup, build, test, platform-specific config, and contributing.

## Build & run

| Goal | Command |
|------|---------|
| Build the solution | `dotnet build` |
| Build specific project | `dotnet build WheelDeck.App/WheelDeck.App.csproj` |
| Run desktop server | `dotnet run --project WheelDeck.App` |
| Run daemon (headless) | `dotnet run --project WheelDeck.App --daemon` |
| Debug logging | `DOTNET_ENVIRONMENT=Development dotnet run --project WheelDeck.App` |

## Test

```bash
dotnet test                                                    # all tests
dotnet test WheelDeck.Tests/WheelDeck.Tests.csproj             # core unit tests only
dotnet test --filter "FullyQualifiedName~PairingManager"       # specific test
dotnet test --collect:"XPlat Code Coverage"                    # with coverage
```

## Key concepts

**VirtualOutputBackend** — the single abstraction for driving a virtual controller:
- `setAxis(AxisType, float)` — steering -1..1, pedals 0..1
- `setButton(ButtonId, bool)` — controller button mapping mode
- `sendKey(KeyCode, bool)` — simulated keypress mapping mode
- `neutralize()` — zero all axes, release all buttons (called on every termination path)
- `shutdown()` — cleanup on server exit

**SessionGate** — single enforcement point: no message reaches `InputMapper` unless it originates from the active, non-expired, non-revoked device.

**PairingManager** — generates pairing codes, validates devices, manages 30-day expiry, triggers `neutralize()` on device switch.

## Platform-specific setup

### Windows (HIDMaestro)
1. Run the app as administrator on first launch — the HIDMaestro driver installs automatically
2. The app prompts you on first launch if the driver is missing

### Linux (uinput)
1. Load kernel module: `modprobe uinput`
2. Set up permissions: `scripts/linux/install-uinput-rules.sh`
3. Follow any distro-specific remediation the script prints (SELinux on Fedora, udev rule install everywhere).

| Distro | Kernel module package | Notes |
|---|---|---|
| Fedora / RHEL (+Nobara) | `sudo dnf install kernel-modules-extra` | SELinux steps per script output |
| Ubuntu / Debian (+Mint, Pop!_OS, Zorin) | built-in, no package | AppArmor stock OK; install udev rule via script output |
| Arch (+Manjaro, EndeavourOS, Garuda) | built into `linux` / `linux-lts` kernel | same udev rule path |


