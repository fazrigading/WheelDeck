# WheelDeck Desktop

C#/.NET 10 desktop server that receives WebSocket input from the phone app and translates it into a virtual game controller. Uses Avalonia UI for the GUI.

## Overview

Runs on Windows (ViGEmBus virtual Xbox controller) or Linux (uinput virtual joystick). Pairing, session management, and input routing are handled in `WheelDeck.Core` with zero platform dependencies. The composition root picks the right backend at startup.

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
│   ├── SetupChecker.cs                # First-run ViGEmBus/uinput check
│   ├── Views/                         # XAML views (connection, pairing, status)
│   └── ViewModels/                    # MVVM view models
├── WheelDeck.Core/                    # Domain logic (no OS dependencies)
│   ├── Protocol/                      # Message models from protocol/schema/
│   ├── Pairing/                       # PairingManager, IPairingStore, session tokens
│   ├── Input/                         # InputMapper, MappingMode
│   └── Network/                       # WebSocketListener, PairingService, SessionGate, HeartbeatMonitor
├── WheelDeck.Backends/
│   ├── Windows/                       # ViGEmBus virtual Xbox 360 controller
│   │   ├── ViGEmClient.cs
│   │   ├── ViGEmXboxBackend.cs
│   │   └── SendInputKeySimulator.cs   # Win32 SendInput for key simulation
│   └── Linux/                         # uinput virtual joystick
│       └── UinputBackend.cs
└── WheelDeck.Tests/                   # xunit unit tests
```

## Prerequisites

| Tool | Minimum |
|------|---------|
| .NET SDK | 10.0+ |
| ViGEmBus driver | Windows only — [ViGEm releases](https://github.com/ViGEm/ViGEm.NET/releases) |
| uinput | Linux only — `sudo dnf install kernel-modules-extra` (Fedora) |

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

### Windows (ViGEmBus)
1. Install ViGEmBus driver from the [official releases](https://github.com/ViGEm/ViGEm.NET/releases)
2. The app prompts you on first launch if missing

### Linux (uinput)
1. Load kernel module: `modprobe uinput`
2. Set up permissions: `scripts/linux/install-uinput-rules.sh`
3. Fedora SELinux: follow the remediation steps the script prints


