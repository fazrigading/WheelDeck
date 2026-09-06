# WheelDeck

Turn an Android or iOS phone into a steering wheel and dashboard control panel for PC racing and trucking simulators. A desktop companion app translates the phone's input into a virtual game controller the simulator reads natively.

Primary target: Euro Truck Simulator 2.

## How it works

1. Phone captures gyroscope steering, touch pedals, and dashboard button presses
2. Phone discovers the desktop server on the local network via mDNS
3. One-time PIN pairing establishes a session
4. State and button messages stream over WebSocket in real time
5. Desktop app drives a virtual Xbox controller (Windows/ViGEmBus) or joystick (Linux/uinput)
6. Simulator reads the virtual controller natively — no game plugins needed

## Components

| Directory | Stack | Description |
|-----------|-------|-------------|
| `mobile/` | Flutter (Dart) | Phone app — sensor capture, WebSocket client, on-screen controls |
| `desktop/` | C#/.NET 10 + Avalonia UI | Desktop server — WebSocket listener, virtual controller backend, pairing |
| `protocol/schema/` | JSON Schema | Shared message formats and control enums (single source of truth) |

## Project structure

See [`docs/project-structure.md`](docs/project-structure.md) for the full repository layout.

## Quick start

### Phone app

```bash
cd mobile
flutter pub get
flutter run
```

### Desktop server

```bash
cd desktop
dotnet build
dotnet run --project WheelDeck.App
```

See `docs/mobile-dev-guide.md` and `docs/desktop-dev-guide.md` for full setup instructions including platform-specific driver requirements.

## Supported platforms

| Platform | Status | Virtual controller |
|----------|--------|--------------------|
| Android | P0 | — |
| iOS | P0 (via PWA) | — |
| Windows | P0 | ViGEmBus (virtual Xbox 360) |
| Linux | P0 | uinput (virtual joystick) |

## Docs

Full specs, guides, and architecture decisions: [`docs/`](docs/)
