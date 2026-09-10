# Mobile developer guide

This guide gets you set up, building, testing, and contributing to the WheelDeck mobile app. It's a Flutter application that captures steering (gyroscope), pedals (touch), and dashboard controls, then streams them over WebSocket to the desktop server.

## Prerequisites

| Tool | Minimum |
|---|---|
| Flutter SDK | 3.13+ |
| Android SDK | API 21+ |
| Chrome (optional) | For PWA/iOS testing |

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

See [`project-structure.md`](./project-structure.md) for the full repository layout.

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
# Unit and widget tests (97 passed on feature/revamp-mobile-ui)
flutter test

# Run a specific test file
flutter test test/ui/features/connection/connection_screen_test.dart

# Run with coverage
flutter test --coverage

# Static analysis (0 issues)
dart analyze --fatal-infos
```

Test files mirror the `lib/` structure under `test/`:

```
test/
├── data/
│   ├── repositories/
│   └── services/
└── ui/
    ├── core/
    └── features/
        ├── connection/   # discovery, FAB ManualAddSheet flow, pairing
        ├── driving/      # PedalPanel drag, WheelView, calibration
        ├── onboarding/
        └── settings/
```

Key test updates in revamp: `connection_screen_test.dart` now taps `manual-add-fab` before asserting `manual-ip`/`manual-port`; `pedal_panel_test.dart` checks `ValueKey('pedal-*')` stable keys. Widget tests use `fake_async` for spring-back and reconnect intervals.

## Key concepts

### Input Capture Layer (`lib/data/services/`)

- **`SteeringSensor`**: Samples the gyroscope, normalizes to `-1.0..1.0` (0 = straight ahead), and applies user-adjustable sensitivity. Call `setCenter()` for calibration. The UI layer and network layer both consume the already-calibrated value. Linked to `DrivingViewModel.recalibrate()` for manual drift correction.
- **`PedalInput`**: Each pedal bar owns its drag-to-pressure mapping (`0.0` at rest, `1.0` at full drag) and its own spring-back release animation. `setReleaseCurve()` makes the curve tunable later. Order/visibility driven by `PedalLayout` (a-d) via `PedalPanel(layout:)`.
- **`DashboardInput`**: Exposes `ControlId` and `ActionType` enums matching `protocol/schema/controls.json`. Actions: `Toggle`, `Press`, `Release`, `HoldConfirm` (used for engine start).
- **`ControllerType` / `PedalLayout` / `GamePreset`**: Settings-only services. `ControllerType` (5 modes: steeringOnly → full), `PedalLayout` (a: AccR BrakeR ClutchL → d: AccR BrakeL no clutch), `GamePreset.ets2` mirrors `desktop/WheelDeck.Core/Input/InputMapper.cs` key/button maps.

### Network Client Layer (`lib/data/services/` + `lib/data/repositories/`)

- **`WheelDeckClient`**: The single entry point for all network communication. Manages the WebSocket connection, sends `state` and `button` messages, and handles pairing. Exposes `ConnectionStatus` (`Disconnected`, `Discovering`, `Connecting`, `PairingRequired`, `Connected`, `Reconnecting`).
- **`Discovery` / `ServerDiscoveryRepository`**: Auto-discovers desktop servers via mDNS broadcast. Falls back to manual IP via `ManualAddSheet` FAB modal when broadcast is blocked.
- **`Pairing` / `SessionRepository`**: Handles the PIN/QR pairing flow and stores the session token locally so future connections skip re-pairing. The token persists until the desktop's 30-day inactivity expiry. PIN field is now `obscureText:false`.
- **`PairedDeviceRepository`**: Persists `host:port` of successfully connected desktops (`SharedPreferences` `wheeldeck.paired_devices`) to split **Paired vs Available** on `ConnectionScreen`.

**Message send rate**: `sendState()` fires on every sensor/touch update tick, not batched or debounced. The desktop uses the `seq` field for ordering.

**Heartbeat**: Sent every ~2s internally by `WheelDeckClient`. Two missed beats make the desktop neutralize output. The client auto-reconnects and transitions to `Reconnecting` status.

### State coordination (`lib/ui/core/` + theming)

- **`ConnectionCoordinator`**: Facade over the layered stack (services, repositories, `ConnectionViewModel` + `PairedDeviceRepository`) that preserves the app-level API: discovery, connect, pairing, connected, reconnect. Forwards state to the UI via `provider`; new code binds to `coordinator.viewModel` with `ListenableBuilder`. Also exposes `pairedServers`/`unpairedServers`.
- **`AppTheme`**: `lib/ui/core/theme/app_theme.dart` — `ColorScheme.fromSeed(blue)` light/dark, `useMaterial3:true`, `ThemeMode.system` (60/30/10, 8pt grid, rounded-16 cards, tinted shadows, 44×44 targets).

### App lifecycle handling

The network client responds to OS lifecycle events automatically via `LifecycleObserver` (`lib/ui/core/lifecycle_observer.dart`), so the UI layer does not need to manage this:

| Event | Behavior |
|---|---|
| Incoming call / `paused`/`detached` | `coordinator.pause()` — disconnect, hold last-known state |
| Notification shade / `inactive` (transient) | No-op — stay connected (fix for Android pane bug) |
| Screen lock / backgrounded | Disconnect gracefully |
| Foregrounded / `resumed` | `coordinator.resume()` — require calibration re-confirm, `lastTarget` auto-reconnect |
| Manual recalibrate | `DrivingView` FAB/AppBar `center_focus_strong` → `recalibrate()` + haptic + SnackBar |
| iOS PWA backgrounded | Reconnect to last-known IP + mDNS discovery in parallel on foreground |

> See [`mobile-interface.md`](./mobile-interface.md#3-app-lifecycle-handling) for the full lifecycle spec and orientation lock requirements.

## Protocol awareness

The mobile app sends two message types over WebSocket (see `protocol/schema/`):

1. **State message** (`state`): Sent continuously with `seq`, `steering`, `accelerator`, `brake`, `clutch`. Latest value wins, no acknowledgment required.
2. **Button message** (`button`): Sent for discrete controls like turn signals, lights, wipers. Uses `ControlId` and `ActionType` from `controls.json`.

Pairing/session messages (`pair_request`, `pair_response`, `heartbeat`, `device_switch`) are handled internally by the `WheelDeckClient` network layer.

## Adding a new dashboard control

1. Add the enum value to `protocol/schema/controls.json`
2. Add the same value to `ControlId` in `mobile/lib/data/services/dashboard_input.dart`
3. Add the same value to `ControlId` in `desktop/WheelDeck.Core/Protocol/ControlId.cs`
4. Add the UI widget in `lib/ui/features/driving/views/`
5. Map the control to a key press or virtual button in the desktop `InputMapper`

> The protocol schema is the single source of truth. Do not add control enums to code without adding them to the schema first.

## Onboarding & permissions

The `lib/ui/features/onboarding/views/onboarding_screen.dart` screen must request:
- **Motion sensors**: needed for gyroscope steering input
- **Local network**: needed for mDNS discovery and WebSocket communication

Both are explained with a clear rationale before the request is made.

## UI shell (M3 revamp v0.1.0)

- **Menu hub**: `MenuScreen` — logo + title, 4 M3 CTAs (Connect `Filled`, Settings `FilledTonal`, About/Donate `Outlined`), 8pt grid, thumb-zone, post-onboarding route (`_Routing` → `MenuScreen` when not driving)
- **Connection**: `ConnectionStatusCard` (bounce + sparkle on connected), paired/unpaired split, `ManualAddSheet` bottom sheet with IP/port filtering, PIN visible
- **Driving**: landscape `WheelView` + `PedalPanel` (layout-aware) + `DashboardPanel`, manual recalibrate FAB + AppBar action
- **Settings**: `SegmentedButton` for mapping/preset, `RadioGroup` for controller type & pedal layout, per-control `Chip` list with edit dialog, reset with confirm
- **About/Donate**: GitHub stars badge via `http` + 3 `url_launcher` links

## Dependencies added in revamp

- `url_launcher ^6.3.2` — external links (About source, Donate)
- `http ^1.6.0` — GitHub stars fetch in About
- `FilteringTextInputFormatter` (flutter/services) — IP/port input filtering, no new dep
