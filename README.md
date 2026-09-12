# WheelDeck

Project Status: **Work-in-Progress**

Turn an Android or iOS phone into a steering wheel and dashboard control panel for PC racing and trucking simulators. A desktop companion app translates the phone's input into a virtual game controller the simulator reads natively.

Exclusively made for Linux and Android/iOS; planned for macOS and Windows.

Primary target: Euro Truck Simulator 2.

## How it works

1. Phone captures gyroscope steering, touch pedals, and dashboard button presses
2. Phone discovers the desktop server on the local network via mDNS
3. One-time PIN pairing establishes a session
4. State and button messages stream over WebSocket in real time
5. Desktop app drives a virtual Xbox controller (Windows/HIDMaestro) or joystick (Linux/uinput)
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

| Platform | Status | Driver | Virtual controller |
|----------|--------|--------|--------------------|
| Android  | P0 | Native     | Fully functional    |
| iOS      | P2 | PWA        | Gyro may not work   |
| Windows  | P1 | HIDMaestro | XBOX 360 Controller |
| Linux    | P0 | uinput     | Virtual Joystick    |

## Docs

Full specs, guides, and architecture decisions: [`docs/`](docs/)
