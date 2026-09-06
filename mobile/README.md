# WheelDeck Mobile

Flutter app that turns a phone into a steering wheel and dashboard control panel for PC racing and trucking simulators.

## Overview

Captures gyroscope steering, touch-based pedals, and discrete dashboard controls, then streams them over WebSocket to the WheelDeck desktop server. Auto-discovers the server on the local network via mDNS.

**Primary target:** Android (native). iOS via PWA (`flutter build web`).

## Architecture

Three-layer structure matching `docs/mobile-interface.md`:

```
lib/
├── main.dart                        # Entry point, Provider scope, routing
├── input/                           # Input Capture Layer
│   ├── steering_sensor.dart         # Gyroscope → -1..1 normalized value
│   ├── pedal_input.dart             # Touch-to-pressure mapping, spring-back
│   └── dashboard_input.dart         # ControlId/ActionType enums from schema
├── network/                         # Network Client Layer
│   ├── wheeldeck_client.dart        # WebSocket connection + message framing
│   ├── discovery.dart               # mDNS auto-discovery + manual IP fallback
│   └── pairing.dart                 # PIN pairing + session token persistence
├── state/
│   └── connection_coordinator.dart  # Central connection lifecycle state machine
└── ui/                              # UI Layer
    ├── connection/                  # Discovery, IP entry, pairing screens
    ├── driving/                     # Combined driving surface
    ├── wheel/                       # On-screen wheel + calibration
    ├── pedals/                      # Vertical draggable pedal bars
    ├── dashboard/                   # Truck-styled control panel
    └── permissions.dart             # Onboarding permission prompts
```

## Prerequisites

| Tool | Minimum |
|------|---------|
| Flutter SDK | 3.13+ |
| Android SDK | API 21+ |
| Chrome (optional) | For PWA/iOS testing |

## Guide

See [`docs/mobile-dev-guide.md`](../docs/mobile-dev-guide.md) for setup, build, test, and contributing.

## Build

| Goal | Command |
|------|---------|
| Run on device/emulator | `flutter run` |
| Run on specific device | `flutter run -d <device-id>` |
| Build APK (debug) | `flutter build apk --debug` |
| Build appbundle (release) | `flutter build appbundle` |
| Build web (PWA for iOS) | `flutter build web` |

## Test

```bash
flutter test                  # unit + widget tests
flutter test --coverage       # with coverage report
```

## Wire protocol

Sends two message types to the desktop server (schemas in `protocol/schema/`):

- **State message** — continuous: `seq`, `steering`, `accelerator`, `brake`, `clutch`. Latest-wins, no ack.
- **Button message** — discrete: `control` (ControlId), `action` (ActionType). Reliable delivery.

Pairing/session messages (`pair_request`, `pair_response`, `heartbeat`, `device_switch`) are handled internally by the network layer.


