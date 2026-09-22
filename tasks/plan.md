# Implementation Plan: Flutter → Kotlin (Android-native) Migration

Status: **ongoing** — Tasks 1–3 complete (2026-09-22).

Rebuild the `mobile/` Flutter app as an Android-native Kotlin + Jetpack Compose app in `android/`, slice by slice, against the same `protocol/schema/` contract. Flutter stays runnable as the working reference until Kotlin reaches functional parity **plus the seven known fixes from `TODO.md`**, then `mobile/` is deleted. Desktop (.NET) is untouched. Local data starts fresh — no SharedPreferences migration.

## Architecture Decisions

- **Android-native Compose, Material 3.** iOS was already P2 with a PWA plan; Flutter was never serving it natively. No KMP machinery.
- **Mirror the existing layering.** `data/` (services + repositories), `domain/` (models), `ui/` (features with `views/` + `view_models/`). One `:app` module, no multi-module.
- **No DI framework.** Manual `AppContainer` with constructor injection, matching the Dart codebase's style.
- **Coroutines + Flow** replace Dart Streams and ChangeNotifiers; **ViewModel + StateFlow** replace `provider`; **data classes** replace `freezed`.
- **Version catalog** (`gradle/libs.versions.toml`); Kotlin 2.x + Compose compiler plugin; minSdk 26, targetSdk 36, compileSdk 37 (Compose BOM 2026.09.00 / compose-ui 1.12.1 requires 37), package `dev.fazrigading.wheeldeck` (already the Flutter applicationId).
- **Tests:** JUnit + `kotlinx-coroutines-test` + OkHttp `MockWebServer` + Robolectric (sensor/permission seams); Compose UI tests only where gestures need them. The 27 Dart test files are ported 1:1 as the parity gate.
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

- [ ] **Task 4: WebSocket client** (M)
  - Port `wheeldeck_client.dart` to OkHttp WebSocket: dial with target/token, JSON framing of state/button/mapping/session messages, standalone heartbeat every ~2s (ADR-0003), fixed-interval auto-reconnect (ADR-0002), disconnect → neutralize signal to consumers.
  - **Acceptance criteria:**
    - [ ] `wheeldeck_client_test` and `heartbeat_test` ports pass (MockWebServer)
    - [ ] Two missed heartbeats surface a neutralize signal; unexpected drops trigger reconnect to last target; manual disconnect stops retries
  - **Verification:** `./gradlew test`.
  - **Dependencies:** Task 2.
  - **Files likely touched:** `.../data/services/wheeldeck_client.kt`, `android/app/src/test/`.
  - **Reference:** `mobile/lib/data/services/wheeldeck_client.dart`, `docs/adr/0002-*`, `docs/adr/0003-*`.

- [ ] **Task 5: Pairing + session** (M)
  - PIN pairing flow, pairing-challenge model, session token issue/reuse, `PairedDevice` persistence in DataStore. Desktop enforces 30-day expiry; phone handles token storage and presentation.
  - **Acceptance criteria:**
    - [ ] `pairing_test` port passes
    - [ ] Token survives app restart; re-pair skipped while token valid
  - **Verification:** `./gradlew test`; manual pair/unpair/restart against real desktop.
  - **Dependencies:** Task 4.
  - **Files likely touched:** `.../data/services/pairing.kt`, `.../data/repositories/paired_device_repository.kt`, `.../data/repositories/session_repository.kt`, `.../domain/models/pairing_challenge.kt`.
  - **Reference:** `mobile/lib/data/services/pairing.dart`, `mobile/lib/domain/models/pairing_challenge.dart`.

- [ ] **Task 6: Connection UI** (M)
  - Compose connection screen (status states, discovery list, manual-add sheet), `ConnectionViewModel`, `ConnectionCoordinator` (status machine + lifecycle observer), connection-mode logic.
  - **Acceptance criteria:**
    - [ ] Full connect flow usable on device: discover → pair → connected; status transitions match Flutter behavior
    - [ ] Lifecycle (background/foreground) triggers reconnect per ADR-0002 semantics
  - **Verification:** `./gradlew test`; manual device walkthrough.
  - **Dependencies:** Tasks 3, 5.
  - **Files likely touched:** `.../ui/features/connection/**`, `.../ui/core/connection_coordinator.kt`, `.../ui/core/lifecycle_observer.kt`, `.../data/repositories/connection_repository.kt`.
  - **Reference:** `mobile/lib/ui/features/connection/**`, `mobile/lib/ui/core/**`.

### Checkpoint A: Connection works end-to-end
- [ ] Kotlin app pairs with a real desktop over Wi-Fi, reconnects after Wi-Fi fade, heartbeats hold
- [ ] Flutter app still builds and `flutter test` passes (regression guard)

### Phase 3: Input capture + driving core

- [ ] **Task 7: Gyro steering** (M)
  - `SensorManager` capture ported from `gyroscope_service.dart` + `steering_sensor.dart`; calibration capture and reconfirm-on-resume (always prompts, per CONTEXT.md); rotation mapper (degrees → −1..1). Sensor stream behind a seam for fake-driven tests.
  - **Acceptance criteria:**
    - [ ] `gyroscope_service_test` and `rotation_mapper_test` ports pass
    - [ ] Calibration reconfirm prompt fires on every resume from background
  - **Verification:** `./gradlew test`; manual device check with real desktop receiving state messages.
  - **Dependencies:** Task 2.
  - **Files likely touched:** `.../data/services/gyroscope_service.kt`, `.../data/services/steering_sensor.kt`, `.../data/services/rotation_mapper.kt`, `.../domain/models/steering_state.kt`.
  - **Reference:** `mobile/lib/data/services/{gyroscope_service,steering_sensor,rotation_mapper}.dart`, `mobile/lib/domain/models/steering_state.dart`.

- [ ] **Task 8: Pedal input** (M)
  - Touch-drag analog 0.0–1.0 with spring-back release, per `pedal_input.dart` + `spring_back.dart`; pedal state model.
  - **Acceptance criteria:**
    - [ ] `spring_back_test` port passes
    - [ ] Release springs back with the same curve as Flutter
  - **Verification:** `./gradlew test`.
  - **Dependencies:** Task 2.
  - **Files likely touched:** `.../data/services/pedal_input.kt`, `.../data/services/spring_back.kt`, `.../data/repositories/pedal_repository.kt`, `.../domain/models/pedal_state.kt`.
  - **Reference:** `mobile/lib/data/services/{pedal_input,spring_back}.dart`, `mobile/lib/domain/models/pedal_state.dart`.

- [ ] **Task 9: Driving view model + send gate + visibility + wheel mode** (M)
  - Port `driving_view_model.dart`, `dashboard_send_gate.dart` (state-send rate gating), `dashboard_visibility.dart`, `controller_visibility.dart`, `wheel_mode.dart`, `camera_pad_mode.dart`, `engine_start_mode.dart`.
  - **Acceptance criteria:**
    - [ ] `dashboard_send_gate_test`, `dashboard_visibility_test`, `wheel_mode_test`, `driving_view_model_test` ports pass
  - **Verification:** `./gradlew test`.
  - **Dependencies:** Tasks 6, 7, 8.
  - **Files likely touched:** `.../ui/features/driving/view_models/driving_view_model.kt`, `.../data/services/{dashboard_send_gate,dashboard_visibility,controller_visibility,wheel_mode,camera_pad_mode,engine_start_mode}.kt`.
  - **Reference:** same names under `mobile/lib/`.

- [ ] **Task 10: Driving screen** (L)
  - Compose driving surface: canvas `RotatableWheel` (finger rotation → 180/270/900/1080/1800/2520 degrees, rotation indicator arc), `TiltReadout`, pedal panels, `CameraPad` (numpad/arrow modes, center recenter/mode-switch, tap-or-hold). **Includes the TODO.md fix: rotate-back-to-zero runs at a constant slow rate at every degree value** (constant-rate return in the mapper; tested at 180 and 2520).
  - **Acceptance criteria:**
    - [ ] `rotatable_wheel_test`, `tilt_readout_test`, `camera_pad_test`, `wheel_view_test`, `pedal_panel_test` ports pass
    - [ ] Rotate-back-to-zero speed is constant (deg/s) regardless of selected rotation degree; verified at 180 and 2520
    - [ ] Full steering + pedal + camera-pad session works on a real device against ETS2
  - **Verification:** `./gradlew test`; manual ETS2 drive session.
  - **Dependencies:** Task 9.
  - **Files likely touched:** `.../ui/features/driving/views/{driving_view,rotatable_wheel,wheel_view,tilt_readout,pedal_panel,camera_pad}.kt`.
  - **Reference:** `mobile/lib/ui/features/driving/views/*`, `TODO.md` Controls item.

### Checkpoint B: Drivable (make-or-break)
- [ ] Real-device ETS2 session: gyro steering, rotatable steering, pedals, camera pad all functional
- [ ] `flutter test` still passes

### Phase 4: Dashboard completeness

- [ ] **Task 11: Rotatable grid layout engine** (M)
  - Port `driving_layout.dart` (546 lines, biggest single port): rotatable grid, blocks, cells, slots, holes, layout presets (Sequential), slot geometry. **Includes three TODO.md fixes, built in while porting:**
    1. Gear button → 2 rows × 1 col (was 2×2)
    2. ACC+BRK pedals → one grouped slot, 4 rows × 3 cols total (was 4×2 each)
    3. Padding between blocks, except along screen edges
  - **Acceptance criteria:**
    - [ ] `driving_layout_test` and `block_grid_test` ports pass, with slot geometry updated to the three fixes
    - [ ] `dashboard_panel_test` port passes; grid renders holes, wheel, pedals, camera pad per Sequential preset
    - [ ] Visual: gaps between blocks, none along screen edges
  - **Verification:** `./gradlew test`; manual device inspection vs `plan/references/` mockups.
  - **Dependencies:** Task 10.
  - **Files likely touched:** `.../data/services/driving_layout.kt`, `.../ui/features/driving/views/{dashboard_panel,block_grid}.kt`.
  - **Reference:** `mobile/lib/data/services/driving_layout.dart`, `TODO.md` Dashboard items 1–3.

- [ ] **Task 12: Dashboard controls** (M)
  - Port control semantics from `input_mapping.dart` + `controller_preset.dart`: turn signals mutually exclusive, hazard ~1.5 Hz independent of signals, light cycle OFF → Parking → Low Beam held on phone, high beam independent, engine start hold-confirm/press modes, unbound controls send nothing (desktop ignores unknowns as safety net). **Includes TODO.md fix: camera pad Up/Down/Left/Right keybinds default to `auto` — no manual keybind prompt on first press in Driving.**
  - **Acceptance criteria:**
    - [ ] `control_mode_test`, `signal_row_test`, `controller_preset_test` ports pass
    - [ ] Camera pad directional keybinds resolve to `auto` defaults with no prompt
  - **Verification:** `./gradlew test`; manual device check of signals/hazard/lights/engine.
  - **Dependencies:** Task 11.
  - **Files likely touched:** `.../data/services/{input_mapping,controller_preset}.kt`, `.../ui/features/driving/views/*.kt` (control slots).
  - **Reference:** `mobile/lib/data/services/{input_mapping,controller_preset}.dart`, `TODO.md` Dashboard item 4.

- [ ] **Task 13: Onboarding + permissions + settings** (M)
  - Port onboarding flow (permissions → discovery/pairing → calibration confirm → driving; each step validates before advancing), `permission_service.dart` behind a seam, settings screen + view model + binding edit dialog. **Includes two TODO.md fixes:** a dedicated Keybind Configuration page inside Settings, and the keybind modal must not resize the dashboard when the keyboard opens (Compose `imePadding` + window `adjustResize` handling — dashboard stays put).
  - **Acceptance criteria:**
    - [ ] `permission_service_test` and `settings_screen_test` ports pass
    - [ ] Onboarding walkthrough completes on a fresh install
    - [ ] Keybind Configuration page reachable from Settings
    - [ ] Opening the keybind modal and showing the keyboard does not resize/shift the dashboard
  - **Verification:** `./gradlew test`; manual fresh-install + settings walkthrough.
  - **Dependencies:** Task 12.
  - **Files likely touched:** `.../ui/features/onboarding/**`, `.../ui/features/settings/**`, `.../data/services/permission_service.kt`, `.../data/repositories/{onboarding,settings}_repository.kt`.
  - **Reference:** `mobile/lib/ui/features/{onboarding,settings}/**`, `TODO.md` Dashboard item 5 + Settings item.

### Checkpoint C: Parity + fixes
- [ ] Side-by-side feature walkthrough vs Flutter app: every feature matches, plus the seven TODO.md fixes verified
- [ ] `./gradlew test` green and `flutter test` green (last regression check)

### Phase 5: Polish + cutover

- [ ] **Task 14: Menu / about / donate screens** (S)
  - Port menu screen, about screen, donate screen (URL launcher → `Intent.ACTION_VIEW`).
  - **Acceptance criteria:**
    - [ ] All three screens render and their external links open
  - **Verification:** `./gradlew test`; manual check.
  - **Dependencies:** Task 13.
  - **Files likely touched:** `.../ui/features/{menu,about,donate}/**`.
  - **Reference:** `mobile/lib/ui/features/{menu,about,donate}/**`.

- [ ] **Task 15: Cutover** (M)
  - Rewrite `docs/mobile-dev-guide.md` for Kotlin, update `README.md` components table and `docs/project-structure.md`, update CI (remove Flutter job), delete `mobile/`, move this plan to `plan/finished/migration-kotlin-1.md` (per repo convention), check off the seven resolved Mobile items in `TODO.md`.
  - **Acceptance criteria:**
    - [ ] `mobile/` deleted; repo builds with only `android/` + `desktop/`
    - [ ] Docs and CI reflect the Kotlin app
    - [ ] Mobile TODO items marked resolved in `TODO.md`
  - **Verification:** full build + test both components; docs review.
  - **Dependencies:** Checkpoint C + Task 14.
  - **Files likely touched:** `mobile/` (delete), `docs/`, `README.md`, `.github/`, `TODO.md`, `plan/`.

### Checkpoint: Complete
- [ ] All acceptance criteria met across Tasks 1–15
- [ ] Ready for review

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
