# Mobile developer guide

This guide gets you set up, building, testing, and contributing to the WheelDeck mobile app. It's a Flutter application that captures steering (gyroscope), pedals (touch), and dashboard controls, then streams them over WebSocket to the desktop server.

> **Terminology**: All component names, layer names, and message types below use the exact vocabulary from [`CONTEXT.md`](../CONTEXT.md). Folder names match layer names, see [`project-structure.md`](./project-structure.md).

## Prerequisites

| Tool | Minimum | Install |
|---|---|---|
| Flutter SDK | 3.13+ | `https://docs.flutter.dev/get-started/install` |
| Android SDK | API 21+ | `flutter doctor` |
| Android Studio (for device emulation) | n/a | `https://developer.android.com/studio` |
| (Optional) Chrome | n/a | For testing the iOS PWA path (`flutter build web`) |

Run `flutter doctor` once and fix every item it flags before proceeding.

## Get started

```bash
cd mobile
flutter pub get
flutter run        # picks a connected device or emulator
```

To build the PWA for iOS testing:

```bash
flutter build web
# serve with: python3 -m http.server 8000 --directory build/web
```

## Project structure

The `mobile/lib/` layout mirrors the three-layer architecture from [`mobile-interface.md`](./mobile-interface.md):

```
lib/
├── main.dart                      # Entry point; sets up Provider scope + initial route
├── input/
│   ├── steering_sensor.dart       # Gyroscope sampling, calibration, sensitivity
│   ├── pedal_input.dart           # Touch-to-pressure mapping, spring-back curves
│   └── dashboard_input.dart       # Control/action enums, press/toggle/hold_confirm
├── network/
│   ├── wheeldeck_client.dart      # WebSocket connection, message framing, heartbeat
│   ├── discovery.dart             # mDNS auto-discovery + manual IP fallback
│   └── pairing.dart               # Pairing flow + session-token persistence
├── ui/
│   ├── connection/                # Discovery, IP entry, pairing screens
│   ├── driving/                   # Combined driving surface (wheel/pedals/dashboard)
│   ├── wheel/                     # On-screen wheel graphic
│   ├── pedals/                    # Vertical draggable pedal bars
│   ├── dashboard/                 # Truck-styled control panel
│   └── permissions.dart           # Onboarding permission prompts (motion + LAN)
└── state/
    └── connection_coordinator.dart  # Central state machine for connection lifecycle
```

> **GUD-001**: Folder names are identical to the layer names in the interface spec. If a bug touches the network layer, look in `lib/network/`.

## Build & run

| Goal | Command |
|---|---|
| Run on a device/emulator | `flutter run` |
| Run on a specific device | `flutter run -d <device-id>` |
| Build APK (debug) | `flutter build apk --debug` |
| Build appbundle (release) | `flutter build appbundle` |
| Build web (PWA for iOS) | `flutter build web` |
| Hot reload | `r` (in `flutter run` session) |
| Hot restart | `R` (in `flutter run` session) |

## Testing

```bash
# Unit and widget tests
flutter test

# Run a specific test file
flutter test test/connection_screen_test.dart

# Run with coverage
flutter test --coverage
```

Test files mirror the `lib/` structure under `test/`:

```
test/
├── input/
│   ├── steering_sensor_test.dart
│   ├── pedal_input_test.dart
│   └── dashboard_input_test.dart
├── network/
│   ├── wheeldeck_client_test.dart
│   ├── discovery_test.dart
│   └── pairing_test.dart
└── ui/
    ├── wheel/
    ├── pedals/
    ├── dashboard/
    └── connection/
```

Widget tests use `fake_async` to control simulated time for spring-back animations and reconnect intervals.

## Key concepts

### Input Capture Layer (`lib/input/`)

- **`SteeringSensor`**: Samples the gyroscope, normalizes to `-1.0..1.0` (0 = straight ahead), and applies user-adjustable sensitivity. Call `setCenter()` for calibration. The UI layer and network layer both consume the already-calibrated value.
- **`PedalInput`**: Each pedal bar owns its drag-to-pressure mapping (`0.0` at rest, `1.0` at full drag) and its own spring-back release animation. `setReleaseCurve()` makes the curve tunable later.
- **`DashboardInput`**: Exposes `ControlId` and `ActionType` enums matching `protocol/schema/controls.json`. Actions: `Toggle`, `Press`, `Release`, `HoldConfirm` (used for engine start).

### Network Client Layer (`lib/network/`)

- **`WheelDeckClient`**: The single entry point for all network communication. Manages the WebSocket connection, sends `state` and `button` messages, and handles pairing. Exposes `ConnectionStatus` (`Disconnected`, `Discovering`, `Connecting`, `PairingRequired`, `Connected`, `Reconnecting`).
- **`Discovery`**: Auto-discovers desktop servers via mDNS broadcast. Falls back to manual IP entry when broadcast is blocked (public Wi-Fi with client isolation).
- **`Pairing`**: Handles the PIN/QR pairing flow and stores the session token locally so future connections skip re-pairing. The token persists until the desktop's 30-day inactivity expiry.

**Message send rate**: `sendState()` fires on every sensor/touch update tick, not batched or debounced. The desktop uses the `seq` field for ordering.

**Heartbeat**: Sent every ~2s internally by `WheelDeckClient`. Two missed beats make the desktop neutralize output. The client auto-reconnects and transitions to `Reconnecting` status.

### State coordination (`lib/state/`)

- **`ConnectionCoordinator`**: Central state machine that manages the connection lifecycle: discovery, connect, pairing, connected, reconnect. Holds the single source of truth for `ConnectionStatus` and exposes it to the UI via `provider`.

### App lifecycle handling

The network client responds to OS lifecycle events automatically, so the UI layer does not need to manage this:

| Event | Behavior |
|---|---|
| Incoming call | Pause input send, hold last-known state locally |
| Screen lock / backgrounded | Disconnect gracefully |
| Foregrounded | Require calibration re-confirm before resuming input |
| iOS PWA backgrounded | Reconnect to last-known IP + mDNS discovery in parallel on foreground |

> See [`mobile-interface.md`](./mobile-interface.md#3-app-lifecycle-handling) for the full lifecycle spec and orientation lock requirements.

## Protocol awareness

The mobile app sends two message types over WebSocket (see `protocol/schema/`):

1. **State message** (`state`): Sent continuously with `seq`, `steering`, `accelerator`, `brake`, `clutch`. Latest value wins, no acknowledgment required.
2. **Button message** (`button`): Sent for discrete controls like turn signals, lights, wipers. Uses `ControlId` and `ActionType` from `controls.json`.

Pairing/session messages (`pair_request`, `pair_response`, `heartbeat`, `device_switch`) are handled internally by the `WheelDeckClient` network layer.

## Adding a new dashboard control

1. Add the enum value to `protocol/schema/controls.json`
2. Add the same value to `ControlId` in `mobile/lib/input/dashboard_input.dart`
3. Add the same value to `ControlId` in `desktop/WheelDeck.Core/Protocol/ControlId.cs`
4. Add the UI widget in `lib/ui/dashboard/`
5. Map the control to a key press or virtual button in the desktop `InputMapper`

> The protocol schema is the single source of truth. Do not add control enums to code without adding them to the schema first.

## Onboarding & permissions

The `lib/ui/permissions.dart` screen must request:
- **Motion sensors**: needed for gyroscope steering input
- **Local network**: needed for mDNS discovery and WebSocket communication

Both are explained with a clear rationale before the request is made, per the onboarding flow spec in [`spec/mobile-onboarding-flow.md`](../spec/mobile-onboarding-flow.md).

## Useful references

- [`mobile-interface.md`](./mobile-interface.md): Full interface specification for all three layers
- [`CONTEXT.md`](../CONTEXT.md): Domain glossary and terminology
- [`project-structure.md`](./project-structure.md): Repository layout rationale
- [`prd.md`](./prd.md#mobile-app): Mobile feature list and requirements
- [`../plan/feature-wheeldeck-v1-1.md`](../plan/feature-wheeldeck-v1-1.md): Implementation tasks (TASK-007 through TASK-040 for mobile)
- [`../docs/adr/`](../docs/adr/): Architecture decisions that affect mobile behavior
