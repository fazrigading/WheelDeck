# Mobile developer guide

Gets you set up, building, testing, and contributing to the WheelDeck phone app. It is an Android-native Kotlin + Jetpack Compose application: it captures steering (rotatable wheel or gyroscope), pedals (touch), and dashboard controls, then streams them over WebSocket to the desktop server.

> Replaces the Flutter guide. The app was migrated from Flutter in the `migrate/flutter-to-kotlin` plan; the archived plan and the Dart layer map are in [`../plan/finished/migration-kotlin-1.md`](../plan/finished/migration-kotlin-1.md).

## Prerequisites

| Tool | Version |
|---|---|
| JDK | 21 (the build targets JVM 17) |
| Android SDK | compileSdk 37, minSdk 26, targetSdk 36 |

The Gradle wrapper pins everything else, so there is no separate SDK install beyond pointing `ANDROID_HOME` at one. `android/local.properties` (`sdk.dir`) is generated per machine and gitignored.

## Get started

```bash
cd android
./gradlew assembleDebug          # build
./gradlew installDebug           # install on a connected device or emulator
```

`compileSdk = 37` is not negotiable: Compose BOM 2026.09.00 (`compose-ui` 1.12.1) requires it.

## Build & run

| Goal | Command |
|---|---|
| Build the debug APK | `./gradlew assembleDebug` |
| Install on a device | `./gradlew installDebug` |
| Build the release APK | `./gradlew assembleRelease` (debug-signed until a release keystore exists) |
| Run every test | `./gradlew test` |
| One test class | `./gradlew testDebugUnitTest --tests '*WheelDeckClientTest*'` |
| Static analysis | `./gradlew lintDebug` |

## Testing

292 unit tests, all on the JVM — no emulator required. They replace a 32-file Dart suite; the two layout-editor files had no Kotlin counterpart (see the cutover note). The suite is fast enough to run on every save; the Android CI job does exactly that.

```
app/src/test/kotlin/dev/fazrigading/wheeldeck/
├── SmokeTest.kt
├── data/
│   ├── repositories/   SettingsRepository bindings, onboarding, discovery
│   └── services/       client, pairing, gate, layout, preset, permissions, links
├── domain/models/      wire contract
└── ui/
    ├── core/           ControlPress, AppShell routing
    └── features/
        ├── connection/ # connection view model
        ├── driving/    driving view model, control cells, grid, wheel, signals
        ├── onboarding/ # onboarding view model
        └── settings/   settings view model
```

The three newest features — menu, about, donate — carry no test file of their own; their testable logic is `ExternalLinks`/`GitHubStars` under `data/services` and `resolvePage` under `ui/core`.

Three rules keep the suite device-free, and they are the reason several classes exist as pure data:

1. **Hide platform APIs behind an interface.** `NsdManager` (`Discovery`), `SensorManager` (`gyroscopeEvents`), permissions (`PermissionService`), and outbound links (`AndroidLinkOpener`) all have a thin platform adapter and a fake. The logic is unit-tested; **the adapters themselves are not** — they need a device, and none of this has run on one.
2. **Extract gesture and render logic from the composable.** A Composable cannot be unit tested here — there is no emulator CI job — so timing and layout decisions live in plain classes: `RotatableWheelModel`, `ControlPress`, `DrivingLayout`, `cellLabel`, `settingsSections`, `resolvePage`. The Composable forwards pointers and reads state.
3. **The network client runs against `MockWebServer`.** `WheelDeckClientTest` covers framing, heartbeat, and reconnect without a desktop.

## Project structure

`dev.fazrigading.wheeldeck`, one `:app` module, no DI framework:

```
android/app/src/main/kotlin/dev/fazrigading/wheeldeck/
├── data/
│   ├── services/       the layer's leaves: sensors, WebSocket, layout, settings
│   └── repositories/   persistence + the settings façade
├── domain/models/      ControlId, ActionType, wire messages, status
└── ui/
    ├── core/           AppShell, ConnectionCoordinator, ControlPress, theme
    └── features/<f>/   views/ (Compose) + view_models/ (ViewModel + StateFlow)
```

Wiring is manual: `WheelDeckApplication` holds a `ConnectionCoordinator`, which builds the repositories, the client, and the four view models. Screens take their view model as a parameter.

Domain terms follow [`../CONTEXT.md`](../CONTEXT.md) exactly — Phone, Desktop, WheelDeckClient, Pairing, Session, Slot, Hole.

## Key concepts

### Input capture (`data/services/`)

- **`GyroscopeService` / `SteeringSensor`**: `gyroscopeEvents(context)` wraps `SensorManager`; `GyroscopeService` integrates the Z axis into a raw angle, and `SteeringSensor` centres and normalizes it to `-1.0..1.0`. The negative sign is deliberate: a clockwise turn must read as positive steering. `setCenter()` is the calibration primitive.
- **`PedalInput`**: each bar owns its drag-to-pressure mapping (`0.0` at rest, `1.0` at full drag) and its own spring-back release. `SpringBack` holds the curve — the ported 300ms/16ms defaults are pinned by tests.
- **`RotationMapper`**: finger rotation in degrees to `-1.0..1.0`. **Return-to-zero runs at a constant rate** at every degree value, not a constant fraction of the range; that was a `TODO.md` fix and it is tested at 180 and 2520.
- **`ControlPress`**: pointer state for one control cell, with no Compose in it. Owns the tap / momentary / hold-confirm / tap-or-hold timing that the grid and the camera pad share.
- **`DashboardSendGate`**: the phone-held state machine on the send path. Drops unbound controls, holds the headlight cycle OFF → Parking → Low, and holds turn/hazard state with a ~1.5Hz blink phase. Left and right are mutually exclusive; hazard is independent of both.

### Network (`data/services/` + `data/repositories/`)

- **`WheelDeckClient`**: the single entry point for the network. WebSocket framing of state, button, mapping, and session messages; a standalone ~2s heartbeat (ADR-0003 — the two-missed-beats neutralize lives desktop-side, the phone does not track misses); fixed-interval auto-reconnect (ADR-0002). Exposes `ConnectionStatus`.
- **`Discovery` / `ServerDiscoveryRepository`**: mDNS via `NsdManager` for `_wheeldeck._tcp.`. Note the trailing dot — Android wants it, Dart did not. Falls back to a manual IP.
- **`PairingController` / `SessionRepository` / `PairedDeviceRepository`**: PIN pairing and the session token in DataStore, so a restart goes straight to Connected until the desktop's 30-day expiry.

**Message send rate**: `sendState()` fires on every sensor/touch tick, not batched. The desktop orders on `seq`.

### State coordination (`ui/core/`)

- **`AppShell`**: the only routing decision is `resolvePage(onboarded, connected, paused, requested)`, a pure function. Onboarding runs once; the menu is the resting state with its pages stacked on it; a live session (connected *or* paused) takes the whole screen.
- **`ConnectionCoordinator`**: builds the stack and owns the view models, so their state survives navigating between screens.
- **`WheelDeckTheme`**: Material 3 from a blue seed, light and dark, 60/30/10, rounded-16 cards.

### App lifecycle

`LifecycleObserver` drives the coordinator, so no screen manages it:

| Event | Behavior |
|---|---|
| `inactive` (notification shade) | No-op — stay connected |
| `onPause` / backgrounded | `coordinator.pause()` — the socket stays open, the session is marked paused |
| `onResume` | `coordinator.resume()` — re-arm the calibration gate, auto-reconnect to the last target |
| Desktop revokes the device | Drop the token and the paired entry; the next connect re-pairs |

The calibration reconfirm is deliberate and unconditional: returning from background always asks, because the gyro may have drifted while the phone was in a pocket.

## Protocol awareness

Two message types go out over the WebSocket (see `protocol/schema/`):

1. **State** (`state`): `seq`, `steering`, `accelerator`, `brake`, `clutch`, plus optional analog camera `cameraX`/`cameraY`. Latest value wins.
2. **Button** (`button`): discrete controls, using `ControlId` and `ActionType` from `controls.json`.

Pairing, heartbeat, and session messages are handled inside `WheelDeckClient`.

`protocol/schema/*.json` is the single source of truth. `ControlIdContractTest` and `WireMessagesTest` pin the Kotlin side against it; if you add a control and forget the schema, those fail.

## Adding a new dashboard control

1. Add the value to `protocol/schema/controls.json`.
2. Add it to `ControlId` in `android/.../domain/models/Controls.kt`.
3. Add the same value to `ControlId.cs` in `desktop/WheelDeck.Core/Protocol/`.
4. Give it a keyboard (and gamepad) entry in `GamePreset` if it should be bound by default — an unbound control renders disabled and the send gate drops it.
5. Give it a cell in `DrivingLayout.sequential` and a short label in `cellLabel`.
6. Pick its interaction in `ControlPress.modeFor` — toggle, momentary, hold-confirm, or tap-or-hold.
7. Map it to a key or virtual button in the desktop `InputMapper`.

Steps 1 and 2 are the contract; the rest is phone-side. A control with no `modeFor` case defaults to momentary, and a control with no label falls back to its wire value.

## Permissions

On Android neither permission the app asks about is a runtime permission, so `AndroidPermissionService` grants both without a dialog:

- the gyroscope needs no permission at all — it is not a protected sensor, and the app does not request `HIGH_SAMPLING_RATE_SENSORS` (it samples at `SENSOR_DELAY_GAME`, not the 200Hz+ that feature gates);
- local network access is gated by Wi-Fi state and the `CHANGE_WIFI_MULTICAST_STATE` manifest entry, not by a prompt.

The `PermissionService` seam stays so the onboarding screen has a real outcome to render, and so a platform that does prompt only has to replace one class. The manifest declares exactly two permissions: `INTERNET` and `CHANGE_WIFI_MULTICAST_STATE`.

## Dependencies

Deliberately short. `OkHttp` covers the WebSocket, the GitHub stars fetch, and `MockWebServer` in tests. `kotlinx-serialization` covers the wire models. DataStore covers preferences. Compose BOM covers the UI. There is no DI framework, no image loader, and no date library.

`material-icons-extended` is included for the menu, about, and donate screens; it is the one dependency that would be worth revisiting if the icon set grew.
