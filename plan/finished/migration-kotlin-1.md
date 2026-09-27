---
goal: Rebuild the phone app as Android-native Kotlin + Jetpack Compose, reaching parity with the Flutter app plus the seven TODO.md fixes, then delete mobile/
version: 1.0
date_created: 2026-09-22
last_updated: 2026-09-27
owner: fazrigading
status: Finished
tags:
  - migration
  - mobile
  - android
  - kotlin
  - compose
---

# Introduction

![Status: Finished](https://img.shields.io/badge/status-Finished-green)

> **2026-09-27:** Cutover complete. `mobile/` is deleted; the Dart source is
> preserved on the `backup/flutter-port` branch. Checkpoints B and C remain open
> because no device session has been run — see
> [`../../tasks/manual-checklist.md`](../../tasks/manual-checklist.md) for the
> outstanding verification and
> [`../../tasks/task-12-leftovers.md`](../../tasks/task-12-leftovers.md) for what
> the cutover cost. What did **not** come across from Flutter: the layout editor,
> three layout presets, the camera pad's simple/analog shapes, the PWA (and with
> it the iOS client), and the gyro-mode layout.

# Implementation Plan: Flutter → Kotlin (Android-native) Migration

Rebuild the `mobile/` Flutter app as an Android-native Kotlin + Jetpack Compose app in `android/`, slice by slice, against the same `protocol/schema/` contract. Flutter stays runnable as the working reference until Kotlin reaches functional parity **plus the seven known fixes from `TODO.md`**, then `mobile/` is deleted. Desktop (.NET) is untouched. Local data starts fresh — no SharedPreferences migration.

## Architecture Decisions

- **Android-native Compose, Material 3.** iOS was already P2 with a PWA plan; Flutter was never serving it natively. No KMP machinery.
- **Mirror the existing layering.** `data/` (services + repositories), `domain/` (models), `ui/` (features with `views/` + `view_models/`). One `:app` module, no multi-module.
- **No DI framework.** Manual `AppContainer` with constructor injection, matching the Dart codebase's style.
- **Coroutines + Flow** replace Dart Streams and ChangeNotifiers; **ViewModel + StateFlow** replace `provider`; **data classes** replace `freezed`.
- **Version catalog** (`gradle/libs.versions.toml`); Kotlin 2.x + Compose compiler plugin; minSdk 26, targetSdk 36, compileSdk 37 (Compose BOM 2026.09.00 / compose-ui 1.12.1 requires 37), package `dev.fazrigading.wheeldeck` (already the Flutter applicationId).
- **Tests:** JUnit + `kotlinx-coroutines-test` + OkHttp `MockWebServer`, with hand-written fakes at the sensor/permission/link seams; Compose UI tests only where gestures need them. The 27 Dart test files are ported 1:1 as the parity gate.
- **Protocol contract:** `protocol/schema/*.json` stays the single source of truth. Kotlin message models must encode/decode compatible with the desktop; contract tests pin this.
- **Freeze rule:** Flutter gets no new features and no bug fixes during migration. The seven `TODO.md` Mobile items are built right the first time in Kotlin as acceptance criteria — no bug-for-bug parity, no double work.

## Dependency Map (Flutter → Kotlin)

| Flutter pkg | Kotlin replacement | Notes |
|---|---|---|
| `sensors_plus` | `SensorManager` (TYPE_GYROSCOPE / TYPE_GAME_ROTATION_VECTOR) | Same device coordinate frame as Flutter — math ports cleanly |
| `multicast_dns` | `NsdManager` | Pitfall: Android wants `_wheeldeck._tcp.` (trailing dot), Dart uses `_wheeldeck._tcp.local` |
| `web_socket_channel` / `stream_channel` | OkHttp WebSocket | MockWebServer for tests |
| `shared_preferences` | DataStore Preferences | Fresh start, no migration |
| `permission_handler` | Native runtime permission APIs | Behind a `PermissionService` seam for testability |
| `provider` | ViewModel + StateFlow | |
| `freezed` | `data class` | Free — no codegen |
| `http` / `url_launcher` | OkHttp / `Intent.ACTION_VIEW` | |

## Task List

### Phase 1: Foundation

- [x] **Task 1: Scaffold Android project** (S)
  - New `android/` Gradle KTS project: version catalog, Kotlin 2.x, Compose BOM, Material 3, package `dev.fazrigading.wheeldeck`, minSdk 26 / targetSdk 36. Manifest permissions (INTERNET, CHANGE_WIFI_MULTICAST_STATE). `data/domain/ui` package skeleton, `AppContainer`, M3 theme ported from `mobile/lib/ui/core/theme/app_theme.dart`, empty shell screen. Extend `.github` CI with an Android build+test job.
  - **Acceptance criteria:**
    - [ ] `./gradlew assembleDebug` builds; app installs and launches on a device
    - [ ] `./gradlew test` green
    - [ ] Theme (colors/typography) matches the Flutter app visually
  - **Verification:** `./gradlew assembleDebug test`; manual install + launch.
  - **Dependencies:** None.
  - **Files likely touched:** `android/**` (new), `.github/workflows/*`.
  - **Reference:** `mobile/lib/ui/core/theme/app_theme.dart`, `mobile/android/app/build.gradle*`.

- [x] **Task 2: Protocol models + contract tests** (M)
  - kotlinx.serialization models for all five schema files (`button_message`, `state_message`, `mapping_message`, `session_messages`, `controls` enums). Port `control_contract_test.dart` and `input_mapping_test.dart` — these define the wire contract with the desktop.
  - **Acceptance criteria:**
    - [ ] Every schema message type has a Kotlin model that round-trips JSON compatible with desktop expectations
    - [ ] `control_contract_test` and `input_mapping_test` ports pass
  - **Verification:** `./gradlew test`.
  - **Dependencies:** Task 1.
  - **Files likely touched:** `android/app/src/main/kotlin/.../domain/models/`, `.../data/services/`, `android/app/src/test/`.
  - **Reference:** `mobile/lib/domain/models/*.dart`, `mobile/lib/data/services/input_mapping.dart`, `protocol/schema/*.json`.

### Checkpoint: Foundation
- [ ] Android project builds and tests run in CI
- [ ] Wire contract pinned by contract tests

### Phase 2: Connection core (highest risk — fail fast on real hardware)

- [x] **Task 3: mDNS discovery** (M)
  - `NsdManager` discovery of `_wheeldeck._tcp.` services; port `discovery.dart` semantics (dedupe, target model, manual IP/port fallback). Hide `NsdManager` behind an interface so discovery logic is testable with a fake.
  - **Acceptance criteria:**
    - [ ] Kotlin app discovers a running desktop on the LAN on a real device
    - [ ] Manual IP add works as fallback
    - [ ] Discovery logic unit-tested via fake (NsdManager service-type format handled once, in one place)
  - **Verification:** `./gradlew test`; manual device check against `dotnet run --project WheelDeck.App`.
  - **Dependencies:** Task 1.
  - **Files likely touched:** `.../data/repositories/server_discovery_repository.kt`, `.../data/services/discovery.kt`, `.../domain/models/discovered_server.kt`.
  - **Reference:** `mobile/lib/data/services/discovery.dart`, `mobile/lib/data/repositories/server_discovery_repository.dart`.

- [x] **Task 4: WebSocket client** (M)
  - Port `wheeldeck_client.dart` to OkHttp WebSocket: dial with target/token, JSON framing of state/button/mapping/session messages, standalone heartbeat every ~2s (ADR-0003), fixed-interval auto-reconnect (ADR-0002), disconnect → neutralize signal to consumers.
  - **Acceptance criteria:**
    - [x] `wheeldeck_client_test` and `heartbeat_test` ports pass (MockWebServer) — 13 tests
    - [x] Heartbeat is keepalive-only (ADR-0003: the two-missed-beats neutralize lives desktop-side, the phone sends beats and doesn't track misses); unexpected drops reconnect to last target; manual disconnect stops retries
  - **Verification:** `./gradlew test`. Done in `0acbdfb`.
  - **Dependencies:** Task 2.
  - **Files likely touched:** `.../data/services/wheeldeck_client.kt`, `android/app/src/test/`.
  - **Reference:** `mobile/lib/data/services/wheeldeck_client.dart`, `docs/adr/0002-*`, `docs/adr/0003-*`.

- [x] **Task 5: Pairing + session** (M)
  - PIN pairing flow, pairing-challenge model, session token issue/reuse, `PairedDevice` persistence in DataStore. Desktop enforces 30-day expiry; phone handles token storage and presentation.
  - **Acceptance criteria:**
    - [x] `pairing_test` port passes — 5 tests
    - [x] Token survives app restart (DataStore Preferences); re-pair skipped while token valid (client goes straight to Connected on restore)
  - **Verification:** `./gradlew test`. Done in `9c4f1a2`. Manual pair/unpair/restart against real desktop deferred to Checkpoint A.
  - **Dependencies:** Task 4.
  - **Files likely touched:** `.../data/services/pairing.kt`, `.../data/repositories/paired_device_repository.kt`, `.../data/repositories/session_repository.kt`, `.../domain/models/pairing_challenge.kt`.
  - **Reference:** `mobile/lib/data/services/pairing.dart`, `mobile/lib/domain/models/pairing_challenge.dart`.

- [x] **Task 6: Connection UI** (M)
  - Compose connection screen (status states, discovery list, manual-add sheet), `ConnectionViewModel`, `ConnectionCoordinator` (status machine + lifecycle observer), connection-mode logic.
  - **Acceptance criteria:**
    - [x] Full connect flow usable on device: discover → pair → connected; status transitions match Flutter behavior
    - [x] Lifecycle (background/foreground) triggers reconnect per ADR-0002 semantics
  - **Verification:** `./gradlew test`; manual device walkthrough.
  - **Dependencies:** Tasks 3, 5.
  - **Files likely touched:** `.../ui/features/connection/**`, `.../ui/core/ConnectionCoordinator.kt`, `.../ui/core/lifecycle_observer.kt`, `.../data/repositories/connection_repository.kt`.
  - **Reference:** `mobile/lib/ui/features/connection/**`, `mobile/lib/ui/core/**`.

### Checkpoint A: Connection works end-to-end
- [x] Kotlin app pairs with a real desktop over Wi-Fi, reconnects after Wi-Fi fade, heartbeats hold
- [x] Flutter app still builds and `flutter test` passes (regression guard)

### Phase 3: Input capture + driving core

- [x] **Task 7: Gyro steering** (M)
  - `SensorManager` capture ported from `gyroscope_service.dart` + `steering_sensor.dart`; calibration capture and reconfirm-on-resume (always prompts, per CONTEXT.md); rotation mapper (degrees → −1..1). Sensor stream behind a seam for fake-driven tests.
  - **Acceptance criteria:**
    - [x] `gyroscope_service_test` and `rotation_mapper_test` ports pass — 8 tests
    - [ ] Calibration reconfirm prompt fires on every resume from background — the rule lives in `ConnectionViewModel.resume()`/`confirmCalibration()` and is tested (4 tests: always re-arms on resume, confirm and disconnect clear it); the prompt UI and gyro re-center land with the driving screen in Task 9/10
  - **Verification:** `./gradlew test`. Manual device check with real desktop receiving state messages deferred to Checkpoint B (needs the driving screen, Task 10).
  - **Dependencies:** Task 2.
  - **Files likely touched:** `.../data/services/gyroscope_service.kt`, `.../data/services/steering_sensor.kt`, `.../data/services/rotation_mapper.kt`, `.../domain/models/steering_state.kt`.
  - **Reference:** `mobile/lib/data/services/{gyroscope_service,steering_sensor,rotation_mapper}.dart`, `mobile/lib/domain/models/steering_state.dart`.

- [x] **Task 8: Pedal input** (M)
  - Touch-drag analog 0.0–1.0 with spring-back release, per `pedal_input.dart` + `spring_back.dart`; pedal state model.
  - **Acceptance criteria:**
    - [x] `spring_back_test` port passes
    - [x] Release springs back with the same curve as Flutter — linear/easeOut/easeInOut match the ported formulas frame by frame, and the ported 300ms/16ms defaults are pinned
  - **Verification:** `./gradlew test`. Devices and the UI land with the driving screen (Task 10).
  - **Dependencies:** Task 2.
  - **Files touched:** `.../data/services/pedal_input.kt`, `.../data/services/spring_back.kt`, `.../domain/models/pedal_state.kt`. No `pedal_repository.kt`: its only job was handing out immutable snapshots, and `PedalInput.state` (StateFlow) does that while also being the raw handle Task 10's pedal panel binds to, so the repository would add a hop and nothing else.
  - **Reference:** `mobile/lib/data/services/{pedal_input,spring_back}.dart`, `mobile/lib/domain/models/pedal_state.dart`.

- [x] **Task 9: Driving view model + send gate + visibility + wheel mode** (M)
  - Port `driving_view_model.dart`, `dashboard_send_gate.dart` (state-send rate gating), `dashboard_visibility.dart`, `controller_visibility.dart`, `wheel_mode.dart`, `camera_pad_mode.dart`, `engine_start_mode.dart`.
  - **Acceptance criteria:**
    - [x] `dashboard_send_gate_test` port passes — 14 tests (12 ported + blink-timer and phase-drop cases)
    - [x] `dashboard_visibility_test` port passes — 13 tests (EngineStartMode + visibility, incl. the legacy controller-visibility migration and its half-written branch)
    - [x] `wheel_mode_test` port passes — 7 tests (WheelMode + RotationDegree per game preset)
    - [x] `driving_view_model_test` port passes — 19 tests (15 ported, 4 new for the gyro-only paths the Dart suite leaves implicit). Two groups are deliberately not ported yet: layout presets (Task 11) and binding resolution (Task 12) both assert on code that has not landed. The gate's `bindingFor` was unbound until Task 12 added the preset tables, so the send path was inert until then.
  - **Verification:** `./gradlew test`.
  - **Dependencies:** Tasks 6, 7, 8.
  - **Files touched:** `.../ui/features/driving/view_models/driving_view_model.kt`, `.../data/services/{settings_store,dashboard_send_gate,dashboard_visibility,controller_visibility,wheel_mode,camera_pad_mode,engine_start_mode,controller_preset,dashboard_input}.kt`, `.../data/repositories/{settings_repository,connection_repository}.kt`, `.../domain/models/wire_messages.kt` (optional `cameraX`/`cameraY` on the state frame), plus `spring_back.kt` folded into the shared store.
  - **Deferred to later tasks, on purpose:** `GamePreset`'s default binding tables and the per-mode overrides (Task 12), pedal sides and camera-control type (Task 12/13), layout, profiles, and the profile-aware `sendMappingMode(preset)` on init (Task 11). Settings persistence lands here rather than in Task 13: one `SettingsStore` behind `SettingsRepository` replaces the per-setting store interfaces, and `SpringBack` folds into it.
  - **Reference:** same names under `mobile/lib/`.

- [x] **Task 10: Driving screen** (L)
  - Compose driving surface: canvas `RotatableWheel` (finger rotation → 180/270/900/1080/1800/2520 degrees, rotation indicator arc), `TiltReadout`, pedal panels, `CameraPad` (numpad/arrow modes, center recenter/mode-switch, tap-or-hold). **Includes the TODO.md fix: rotate-back-to-zero runs at a constant slow rate at every degree value** (constant-rate return in the mapper; tested at 180 and 2520).
  - **Acceptance criteria:**
    - [x] `rotatable_wheel_test` port passes — 10 tests on `RotatableWheelModel` (5 of the 7 Flutter cases; the arc's pixel scan is pinned as arc geometry in `RotationMapperTest` instead, and the multi-touch case is one pointer model)
    - [x] `tilt_readout_test` port passes — marker fraction
    - [x] `wheel_view_test` port passes — 3 tests, turns mapping
    - [x] `pedal_panel_test` port passes — pressure mapping, clamping, hues, and the drag→`PedalInput` wiring (the rendered-bar cases need a device)
    - [x] `camera_pad_test` port passes — 14 tests across the cell mapping, labels, enabled state, and `ControlPress` (10 tests) which owns the tap/hold timing the pad cells use
    - [x] Rotate-back-to-zero speed is constant (deg/s) regardless of selected rotation degree; verified at 180 and 2520
    - [ ] Full steering + pedal + camera-pad session works on a real device against ETS2 — needs a device; Checkpoint B
  - **Verification:** `./gradlew test`. Widget-level gesture and pixel tests are Compose UI tests (`androidTest`), and this repo has no emulator job, so the gesture/timing logic is extracted into `RotatableWheelModel` and `ControlPress` and unit-tested instead; the Composables forward pointers and render state. The screen is not wired into `MainActivity` yet — that happens with the dashboard grid (Task 11).
  - **Dependencies:** Task 9.
  - **Files touched:** `.../ui/features/driving/views/{driving_screen,rotatable_wheel_model,rotatable_wheel,wheel_view,tilt_readout,pedal_panel,camera_pad}.kt`, `.../ui/core/control_press.kt`, `.../data/services/rotation_mapper.kt` (constant-rate return + arc geometry).
  - **Deferred, on purpose:** the camera pad's simple and analog shapes (they need `CameraControlType`, which lands with the camera-type settings in Task 12), the dashboard grid and its control cells (Task 11/12), pedal-side layout order, and the hold haptic (Android's `LocalHapticFeedback` needs a composable, so it lands with the grid's control visuals).
  - **Reference:** `mobile/lib/ui/features/driving/views/*`, `TODO.md` Controls item.

### Checkpoint B: Drivable (make-or-break) — **open**
- [ ] Real-device ETS2 session: gyro steering, rotatable steering, pedals, camera pad all functional
- [ ] `flutter test` still passes — moot at cutover; the Kotlin suite is green (292) and the Dart source is on `backup/flutter-port`

### Phase 4: Dashboard completeness

- [x] **Task 11: Rotatable grid layout engine** (M)
  - Port `driving_layout.dart` (546 lines, biggest single port): rotatable grid, blocks, cells, slots, holes, layout presets (Sequential), slot geometry. **Includes three TODO.md fixes, built in while porting:**
    1. Gear button → 2 rows × 1 col (was 2×2)
    2. ACC+BRK pedals → one grouped slot, 4 rows × 3 cols total (was 4×2 each)
    3. Padding between blocks, except along screen edges
  - **Acceptance criteria:**
    - [x] `driving_layout_test` port passes — 20 tests, with the slot geometry updated to the three fixes
    - [x] `block_grid_test` port passes — 9 geometry tests; the grid renders holes, wheel, pedals, and camera pad per the Sequential preset through `BlockGrid` (the widget-tree assertions need a device, as in Task 10)
    - [x] `dashboard_panel_test` port passes — 5 presentation tests; the tap, hold, and gate events it drives were already covered by `ControlPressTest` and `DashboardSendGateTest`
    - [x] Gaps between blocks, none along the screen edges — `toPaddedPixels` insets each non-edge side by half the padding, so neighbours are exactly one gap apart and the outer blocks stay flush
  - **Verification:** `./gradlew test`. Visual inspection against `plan/references/` needs a device; Checkpoint B.
  - **Dependencies:** Task 10.
  - **Files touched:** `.../data/services/driving_layout.kt`, `.../ui/features/driving/views/{block_grid,block_geometry}.kt`.
  - **The three TODO.md fixes:** the gear cells are 2x1 (was 2x2); the accelerator and brake are one `SlotKind.PedalGroup` 4x3 (was two 4x2); blocks are padded apart but flush with the screen edges. The cells the first two free became explicit holes, so the grid still tiles all 120 cells.
  - **Deferred, on purpose:** the grid's short cell labels (`DashboardPanel.gridLabel`, e.g. `GEAR+`) — cells print their wire value until the control visuals land in Task 12; the layout *edit* API (`applyMove`, `addControl`, `removeSlot`, `freeSpans`, modules) and `LayoutProfileStore` — they arrived with the custom-layout work in #76 and belong with the layout editor and profile settings (Task 12/13). `DrivingUiState.layout` therefore always holds the Sequential preset until profile selection lands.
  - **Reference:** `mobile/lib/data/services/driving_layout.dart`, `TODO.md` Dashboard items 1–3.

- [x] **Task 12: Dashboard controls** (M)
  - Port control semantics from `input_mapping.dart` + `controller_preset.dart`: turn signals mutually exclusive, hazard ~1.5 Hz independent of signals, light cycle OFF → Parking → Low Beam held on phone, high beam independent, engine start hold-confirm/press modes, unbound controls send nothing (desktop ignores unknowns as safety net). **Includes TODO.md fix: camera pad Up/Down/Left/Right keybinds default to `auto` — no manual keybind prompt on first press in Driving.**
  - **Acceptance criteria:**
    - [x] `controller_preset_test` port passes — 9 tests, with the camera-pad `auto` alias
    - [x] `control_mode_test` port passes — 8 tests (the mode table, engine start's setting override, and the preset tables)
    - [x] `signal_row_test` port passes — 6 tests. The suite's on-screen placement assertions (block A in rotatable mode, above the left pedal column in gyro mode) need a device; what is unit-tested is the behaviour they guard: one cell per signal, toggle mode, bound in both mapping modes so the cells never ask for a keybind, and the gate's mutual exclusion, hazard independence, light cycle, and high-beam independence. The gyro signal *row* is part of the gyro-mode layout, which has not landed yet
    - [x] Camera pad directional keybinds resolve to `auto` defaults with no prompt — all 13 `camera_pad_*` controls, not just the four the TODO names: the diagonals, recenter, and the arrow set are equally unbound today and would prompt the same way. `GamePreset.bindingFor` falls back to `auto` for the whole prefix in **both** mapping modes, so the first press sends instead of asking. The alias is a separate fallback, not entries in the mirrored ETS2 tables, which stay byte-faithful to `controller_preset.dart`
  - **Verification:** `./gradlew test` (236 tests). `assembleDebug` and `lintDebug` clean. Manual device check of signals/hazard/lights/engine deferred to Checkpoint B.
  - **Dependencies:** Task 11.
  - **Files touched:** `.../data/services/controller_preset.kt` (the ETS2 keyboard/gamepad tables + `bindingFor`), `.../data/repositories/settings_repository.kt` (per-mode binding overrides and `resolveBinding`), `.../ui/features/driving/view_models/driving_view_model.kt` (resolves the binding table and feeds the send gate), `.../ui/features/driving/views/block_grid.kt` (the short cell labels Task 11 deferred), `.../ui/features/driving/views/driving_screen.kt`.
  - **Deferred, on purpose:** the binding-edit dialog and the `onBindRequested` tap-through — a cell that is unbound renders disabled and taps do nothing, and the settings page that opens the dialog is Task 13. Pedal sides and the full `resetAll` stay there too. The camera pad's simple and analog shapes still need `CameraControlType`.
  - **Reference:** `mobile/lib/data/services/{input_mapping,controller_preset}.dart`, `TODO.md` Dashboard item 4.

- [x] **Task 13: Onboarding + permissions + settings** (M)
  - Port onboarding flow (permissions → discovery/pairing → calibration confirm → driving; each step validates before advancing), `permission_service.dart` behind a seam, settings screen + view model + binding edit dialog. **Includes two TODO.md fixes:** a dedicated Keybind Configuration page inside Settings, and the keybind modal must not resize the dashboard when the keyboard opens (Compose `imePadding` + window `adjustResize` handling — dashboard stays put).
  - **Acceptance criteria:**
    - [x] `permission_service_test` port passes — 10 tests. `AndroidPermissionService` grants both without a dialog, because neither is a runtime permission on Android: the gyroscope needs only the `HIGH_SAMPLING_RATE_SENSORS` feature, and local network access is gated by Wi-Fi plus the `CHANGE_WIFI_MULTICAST_STATE` manifest entry. No `permission_handler` equivalent dependency needed
    - [x] `settings_screen_test` port passes — 12 tests on `settingsSections`, the wheel-mode and layout rule the widget suite exercises. Its four layout-profile cases are deferred: the profile store and the three extra presets are Task 11's custom-layout work (#76), not this task's
    - [x] Onboarding walkthrough completes on a fresh install — `AppShell` gates the *screen* order: onboarding must be complete, then the connection screen until `Connected`, then driving. The onboarding step itself does **not** block on a denied permission, matching Flutter, because a denied sensor still drives the rotatable wheel and a denied network still reaches a manually-entered desktop; the spec's "each step validates before advancing" is the shell's gate, not a permission check. `OnboardingViewModelTest` covers 6 states
    - [x] Keybind Configuration page reachable from Settings — a `SettingsSection` that opens a second page, so a 92-row list stays out of the settings scroll. Tapping an unbound grid cell opens the same dialog from the dashboard, which is the leftover `tasks/task-12-leftovers.md` flagged
    - [ ] Opening the keybind modal and showing the keyboard does not resize/shift the dashboard — **implemented, unverified.** `decorFitsSystemWindows = false` so the dialog is laid out against the raw window and receives the IME inset, plus `Modifier.imePadding` so it lifts above the keyboard. The dialog window deliberately keeps its inherited `softInputMode`: while a dialog holds IME focus the activity window is not the resize target, so the dashboard keeps its height regardless, and forcing `SOFT_INPUT_ADJUST_NOTHING` would risk suppressing `WindowInsets.ime` on API 30+ — defeating the `imePadding` that does the work. The activity declares `adjustResize` so the settings list scrolls. Confirming the dashboard does not shift needs a device; on the handoff list
  - **Verification:** `./gradlew test` (275 tests), `assembleDebug` and `lintDebug` clean. Manual fresh-install + settings walkthrough is on the handoff list.
  - **Dependencies:** Task 12.
  - **Files touched:** `.../data/services/{permission_service,pedal_sides,camera_control_type}.kt`, `.../data/repositories/{onboarding,settings}_repository.kt`, `.../ui/features/onboarding/**`, `.../ui/features/settings/**`, `.../ui/core/{app_shell,connection_coordinator}.kt`, `.../ui/features/driving/views/{block_grid,camera_pad,driving_screen}.kt`, `.../ui/features/connection/views/connection_screen.kt` (a settings entry point, since Settings is unreachable otherwise), `MainActivity.kt`, `AndroidManifest.xml`.
  - **Deferred, on purpose:** the layout-profile settings section and `LayoutProfileStore` (Task 11's #76 work) — which also defers the camera section's "hide when the layout has no camera pad slot" half, so that rule is currently rotatable-only; the camera pad's simple and analog shapes, which need `CameraControlType` to actually render; the menu/about/donate screens the settings gear will eventually sit beside (Task 14); and the driving screen's landscape lock, which the Flutter app sets and clears around the driving view rather than in the manifest.
  - **Reference:** `mobile/lib/ui/features/{onboarding,settings}/**`, `TODO.md` Dashboard item 5 + Settings item.

### Checkpoint C: Parity + fixes — **open**
- [ ] Side-by-side feature walkthrough vs Flutter app: every feature matches, plus the seven TODO.md fixes verified
- [ ] `./gradlew test` green — **done**, 292 tests
- [ ] Side-by-side walkthrough — **not done**, and it cannot pass as written. The
      cutover dropped the layout editor, three layout presets, the camera pad's
      simple/analog shapes, the PWA, and the gyro-mode layout, so parity is short
      by those. See [`../../tasks/task-12-leftovers.md`](../../tasks/task-12-leftovers.md)

### Phase 5: Polish + cutover

- [x] **Task 14: Menu / about / donate screens** (S)
  - Port menu screen, about screen, donate screen (URL launcher → `Intent.ACTION_VIEW`).
  - **Acceptance criteria:**
    - [x] All three screens render and their external links open. The link logic is unit-tested: `ExternalLinksTest` pins the URLs (absolute https, no duplicates, repo and API agree) and `GitHubStarsTest` pins the fetch and its failure path. `AppShellRoutingTest` pins the routing against the same `resolvePage` the composable calls. The rendering and the actual `startActivity` need a device
    - [x] The menu is the app's resting state, matching `main.dart`'s `_Routing` — the Kotlin `AppShell` had been showing the connection screen directly, so the hub never existed
  - **Verification:** `./gradlew test` (292 tests), `assembleDebug` and `lintDebug` clean. Manual link-tapping needs a device.
  - **Dependencies:** Task 13.
  - **Files touched:** `.../data/services/ExternalLinks.kt` (the URLs, the `LinkOpener` seam, the stars source), `.../ui/features/{menu,about,donate}/views/*.kt`, `.../ui/core/AppShell.kt` (the menu hub and its pages), `.../ui/core/LinkLauncher.kt`, `.../ui/core/ConnectionCoordinator.kt`, `app/build.gradle.kts` (`buildConfig` for the version).
  - **What the reviews caught, because none of it showed up in a test:**
    - `AndroidLinkOpener` called `startActivity` from the *application* context, which throws without `FLAG_ACTIVITY_NEW_TASK` — every one of the five links would have crashed. The catch was also narrowed to `ActivityNotFoundException`, so nothing else could reach the failure message
    - The driving screen's settings control had become dead: the `when` tested `Connected` before the destination, so the assignment was stored and never rendered
    - `Page` was never reset when a session ended, so a driver whose desktop quit landed back on the Connect screen instead of the menu
    - No `BackHandler`, so system back finished the Activity instead of returning to the menu — and the Connect screen had no back affordance at all
    - `isPaused` was dropped from the routing gate, so a heartbeat timeout *while backgrounded* would strand the driver on the menu
    - `resolvePage` had no test: the first `AppShellRoutingTest` re-implemented the rule privately and passed with `AppShell` deleted
  - **Unrequested change, recorded:** the connection screen's settings gear was removed. The menu now owns that route, and a gear on a screen the menu already sits behind was a duplicate. Settings is reachable from the hub and mid-session.
  - **Deferred, on purpose:** the Dart's two-step URL fallback (`externalApplication` then `platformDefault`) is not worth porting — on Android `externalApplication` is a plain `ACTION_VIEW`, which is what this does, and every browser registers an https handler.
  - **Reference:** `mobile/lib/ui/features/{menu,about,donate}/**`.

- [x] **Task 15: Cutover** (M)
  - Rewrite `docs/mobile-dev-guide.md` for Kotlin, update `README.md` components table and `docs/project-structure.md`, update CI (remove Flutter job), delete `mobile/`, move this plan to `plan/finished/migration-kotlin-1.md` (per repo convention), check off the seven resolved Mobile items in `TODO.md`.
  - **Acceptance criteria:**
    - [x] `mobile/` deleted; repo builds with only `android/` + `desktop/`
    - [x] Docs and CI reflect the Kotlin app
    - [x] Mobile TODO items marked resolved in `TODO.md`, each annotated with whether it is device-verified
  - **Verification:** both components green at cutover — `./gradlew test` 292, `assembleDebug`, `lintDebug`, `dotnet test` 70. Every relative markdown link in the repo resolves. What the cutover *cost* — the layout editor, three layout presets, the camera pad's simple/analog shapes, the PWA and the iOS client, the gyro-mode layout — is recorded in [`../../tasks/task-12-leftovers.md`](../../tasks/task-12-leftovers.md) and as new entries in `TODO.md`.
  - **Dependencies:** Checkpoint C + Task 14.
  - **Files likely touched:** `mobile/` (delete), `docs/`, `README.md`, `.github/`, `TODO.md`, `plan/`.

### Checkpoint: Complete — **partially met**
- [x] All fifteen tasks implemented, each with its ported tests green
- [x] `mobile/` deleted; the repo builds and tests with only `android/` + `desktop/`
- [ ] Every acceptance criterion verified — the on-hardware ones are not. Two
      acceptance criteria in Tasks 3, 6, 7, and 10 are device checks that have
      never been run, and Task 13's Dashboard 5 fix is implemented but unverified
- [ ] Parity with the Flutter app — short by the unported features listed above

## Manual Verification

On-device steps live in [`tasks/manual-checklist.md`](../../tasks/manual-checklist.md). Checkpoint B is open: no task past Task 6 has been exercised on hardware.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| `NsdManager` semantics differ from `multicast_dns` (service-type format, name casing, TXT records) | High | Discovery is Task 3 — earliest real-hardware check; manual-IP fallback already exists; service-type format handled in exactly one place |
| Android sensor frames/axes differ from Flutter | High | Same underlying `SensorManager` on Android — port math verbatim + ported gyro tests; calibration reconfirm covers residual drift |
| Rotatable-wheel gesture math regressions | High | `rotation_mapper` tests ported before UI; constant-speed return behavior gets explicit tests at 180 and 2520 |
| Backgrounding/heartbeat behavior differs (Android lifecycle vs Dart observer) | Med | ADR-0002/0003 semantics pinned by ported tests; real background/foreground test in Checkpoint A |
| Keyboard/IME handling differs from Flutter | Med | Explicit acceptance criterion in Task 13 with Compose `imePadding` |
| Scope creep via Flutter fixes | Med | Freeze rule: no Dart changes; TODO items land as Kotlin acceptance criteria |

## Open Questions

Resolved during planning: target = Android-native; strategy = parallel until parity; docs = `tasks/` (this file + `tasks/todo.md`) with long-lived guide in `docs/migration-kotlin.md`; local data = fresh start; app dir = `android/`; widget-test depth = unit tests ported 1:1, Compose UI tests only where gestures require them.
