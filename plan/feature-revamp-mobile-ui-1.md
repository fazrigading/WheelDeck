---
goal: Revamp mobile UI to Material Design 3 with new Menu, Connect, Driving, Settings, About, Donate flows
version: 1.0
date_created: 2026-09-09
last_updated: 2026-09-09
owner: fazrigading
status: Draft
tags:
  - feature
  - ux
  - ui
  - material-design-3
  - mobile
---

# Introduction

![Status: Draft](https://img.shields.io/badge/status-Draft-yellow)

Current mobile app has 3 top-level screens (Onboarding → Connection → Driving) with no app shell. `ConnectionScreen` (mobile/lib/ui/features/connection/views/connection_screen.dart:16) mixes discovery, manual IP, and PIN in one column; `SettingsScreen` (mobile/lib/ui/features/settings/views/settings_screen.dart:13) is a 2-radio list; `DrivingView` (mobile/lib/ui/features/driving/views/driving_view.dart:34) hides calibration behind lifecycle only. TODO.md on `feature/revamp-mobile-ui` asks for a full M3 revamp: new Menu hub, Connect card + paired/unpaired separation + FAB modal, Driving recalibration + lifecycle bug fix, Settings presets/layouts, About + Donate.

This plan sequences the work so each phase is shippable and testable. Stack: Flutter `ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(...))`, `NavigationDrawer`/`FilledButton`/`Card`/`FAB`/`ModalBottomSheet`, `FilteringTextInputFormatter`.

## 1. Requirements & Constraints

- **REQ-001 Menu**: New `MenuScreen` with WheelDeck logo, title, and 4 M3 buttons — Connect, Settings, About, Donate. Entry point after onboarding. Follows M3 layout (centered logo, 16-24dp padding, 8pt grid).
- **REQ-002 Connect — Status**: Card showing `ConnectionStatus` (disconnected/discovering/connecting/pairingRequired/reconnecting/connected) with icon + color (M3 `colorScheme` roles, not hardcoded green). Replaces plain `ConnectionStatusBanner` text.
- **REQ-003 Connect — Paired vs Unpaired**: Split discovered servers into paired-previously vs new/unpaired. Paired data: persist via `SharedPreferences` or `SessionRepository` token existence.
- **REQ-004 Connect — Manual Add**: Remove inline IP/Port row; replace with M3 FAB (`Icons.add`) opening `ModalBottomSheet`/`Dialog` with form. Valid on submit.
- **REQ-005 Connect — Input filtering**: IP field allows `0-9` + `.` only; Port allows `0-9` only. Use `FilteringTextInputFormatter`.
- **REQ-006 Connect — PIN**: `obscureText: false` (currently true at connection_screen.dart:237).
- **REQ-007 Driving — Recalibration**: Manual zeroing/recalibration button (FAB or AppBar action) calling `SteeringSensor.setCenter()` / `DrivingViewModel.confirmCalibration()` even when not `awaitingCalibration`. For gyro drift / phone moved.
- **REQ-008 Driving — Lifecycle bug**: Opening notification pane (Android `inactive`/`paused`) currently triggers `LifecycleObserver.didChangeAppLifecycleState` → `coordinator.pause()` → disconnect. Swipe-back should stay connected; if disconnect unavoidable, auto-reconnect on `resumed` without requiring manual calibration gate. Fix is to distinguish `inactive` (transient, e.g. notification shade) from `paused`.
- **REQ-009 Settings — Input mapping**: Manage per-control bindings for both `InputMapping.keyboard` and `InputMapping.gamepad`. Editable list; persists via `SharedPreferences`.
- **REQ-010 Settings — Presets**: Developer presets: ETS2 + future games. Stored as `Map<ControlId, KeyCode/ButtonId>`.
- **REQ-011 Settings — Controller type**: Selector: steering only / steering+3pedals / steering+2pedals / steering+dashboard / full preset.
- **REQ-012 Settings — Layout**: Pedal layout variants: a) Acc R/Brake R/Clutch L  b) Acc R/Brake L/Clutch L  c) A w/o clutch  d) B w/o clutch. Drives `PedalPanel` order/visibility.
- **REQ-013 Settings — Reset**: Reset to default button (confirm dialog).
- **REQ-014 About**: Developer credit, source code link, GitHub Stars button + badge count (fetch `https://api.github.com/repos/fazrigading/WheelDeck` or shields.io badge).
- **REQ-015 Donation**: Links to buymeacoffee, paypal, ko-fi (launch via `url_launcher`).
- **REQ-016 M3 System**: App-wide M3 theming: `useMaterial3: true`, dynamic `ColorScheme.fromSeed(seedColor)`, `TextTheme` via `ThemeData` (max 4 sizes, 2 weights), 8pt spacing, card `16-24dp` padding, tinted shadows.

- **CON-001**: Keep existing MVVM — ViewModels own state, Views are `ListenableBuilder`. New screens follow `SettingsScreen` pattern (optional `viewModel` override).
- **CON-002**: No new navigation package unless needed. `MaterialPageRoute` + `Navigator` suffices; evaluate `go_router` only if deep-link needed.
- **CON-003**: `connection_coordinator.dart:14` already routes via `_RoutingState`; Menu insertion must not break `isPaused`/`connected` → `DrivingView` gate.
- **GUD-001**: Follow `docs/project-structure.md` — new screens under `mobile/lib/ui/features/<feature>/views/`.
- **PAT-001**: Input filtering via `FilteringTextInputFormatter.allow(RegExp(...))` — stdlib, no dep.

## 2. Implementation Steps

### Phase 0 — Foundation (M3 theme + shell) — unblocks all UI

- **GOAL-001**: Establish M3 design tokens and Menu shell

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-001 | Enable M3 in `mobile/lib/main.dart:25` — `ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue), textTheme: ...)` and dark variant `ThemeData.dark(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark))`. Add `themeMode` if desired. Extract `AppTheme` to `mobile/lib/ui/core/theme/app_theme.dart`. |  |  |
| TASK-002 | Create `mobile/lib/ui/features/menu/views/menu_screen.dart` — M3 scaffold: centered `SafeArea` + `Column` with logo (`Image.asset` or `Icon`), `Text('WheelDeck', style: textTheme.headlineMedium)`, subtitle, 4 `FilledButton`/`FilledTonalButton` + `OutlinedButton` for Connect/Settings/About/Donate. 8pt grid spacing (16,24,32). Respects `AGENTS.md` terse style. |  |  |
| TASK-003 | Insert Menu into routing: `mobile/lib/main.dart:60` `_RoutingState` — after onboarding check, if not connected/paused, return `MenuScreen` instead of direct `ConnectionScreen`. `Menu → Connect` via `Navigator.push`. Add `WillPopScope` handling. |  |  |
| TASK-004 | Add placeholder `AboutScreen` and `DonateScreen` stubs under `ui/features/about/` and `ui/features/donate/` so Menu buttons navigate without crash. |  |  |

### Phase 1 — Connect page revamp

- **GOAL-002**: Status card, paired/unpaired separation, FAB modal, input fixes

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-005 | Replace `ConnectionStatusBanner` (connection_screen.dart:269) with M3 `Card.filled`/`Card.outlined` showing status icon + label + progress indicator for `connecting/reconnecting/discovering`. Color via `colorScheme.primary/error/tertiary`, not hardcoded `Colors.green`. |  |  |
| TASK-006 | Add paired persistence: extend `SessionRepository` or new `PairedDeviceRepository` (SharedPreferences `StringList` of `host:port`) saving on `pairingAccepted`. Expose `List<String> pairedIds` to `ConnectionViewModel`. Split `servers` into `pairedServers`/`unpairedServers` getters. |  |  |
| TASK-007 | Update `ConnectionScreen._buildDiscovery` (73) to render two `ListView` sections: `Paired devices` (with `Icons.history` + "Tap to reconnect") and `Available on this Wi-Fi` (new devices). Empty states via M3 `Card` + illustration + CTA per skill guidance. |  |  |
| TASK-008 | Replace inline `_ManualEntry` row (114) with M3 `FloatingActionButton` (`Icons.add`) anchored bottom-end. On tap, show `showModalBottomSheet` with `ManualAddSheet` containing IP + Port `TextField`s + `FilledButton('Connect')`. |  |  |
| TASK-009 | Add `FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))` to IP field and `FilteringTextInputFormatter.digitsOnly` to Port field. Add `TextInputType.number` + `TextInputType.numberWithOptions(decimal: true)` already partially present (164). Validate IP with `RegExp` on submit; show `InputDecoration.errorText` if invalid. |  |  |
| TASK-010 | Set `obscureText: false` on `_PairingPrompt` PIN field (237). Optionally add `suffixIcon: IconButton(Icons.visibility)` toggle. |  |  |
| TASK-011 | Polish `ConnectionScreen` AppBar per M3: `CenterAligned` title, `SearchBar` future-ready, refresh as `IconButton.filledTonal`. Put primary Connect CTA in thumb zone (bottom 1/3) via `bottomNavigationBar` or FAB. |  |  |

### Phase 2 — Driving page

- **GOAL-003**: Manual recalibration + lifecycle fix

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-012 | Add recalibration button to `DrivingView` — `FloatingActionButton.small` or `AppBar` action `Icons.center_focus_strong` tooltip "Recalibrate / Zero". Calls `_viewModel.confirmCalibration()` or new `_viewModel.recalibrate()` that does `sensorRepository.setCenter()` without requiring `awaitingCalibration`. |  |  |
| TASK-013 | Add `recalibrate()` to `DrivingViewModel` (driving_view_model.dart:113) — `setCenter()` + `notifyListeners()`, does not touch `awaitingCalibration` gate. |  |  |
| TASK-014 | Fix lifecycle bug: edit `LifecycleObserver.dart:16` — treat `AppLifecycleState.inactive` as transient (notification shade) → do NOT call `coordinator.pause()`. Only `paused`/`detached` triggers pause. On `resumed`, if was only `inactive`, skip `isPaused` flag; if was `paused`, keep existing `resume()` + `CalibrationOverlay` gate. Alternative: debounce `inactive` with 300ms timer; cancel if `resumed` within window. Verify on Android real device. |  |  |
| TASK-015 | If disconnect unavoidable (OS kills socket), make `resume()` auto-reconnect: `DrivingView._onCalibrationConfirmed` already calls `coordinator.connect(lastTarget)` — ensure `connection_repository.dart` retains `lastTarget` across pause and `WheelDeckClient` heartbeat survives short interruptions (`wheeleddeck_client.dart:167`). Add reconnect attempt in `ConnectionViewModel.resume()` if `lastTarget != null`. |  |  |

### Phase 3 — Settings page

- **GOAL-004**: Presets, controller type/layout, reset

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-016 | Extend `InputMapping` (input_mapping.dart:4) or new `ControllerPreset` model — `ETS2Preset` with `Map<ControlId, KeyCode>` and `Map<ControlId, ButtonId>` mirroring `desktop/WheelDeck.Core/Input/InputMapper.cs:13`. Store presets as `const` maps. Add `GamePreset` enum + `PresetRepository`. |  |  |
| TASK-017 | Add `ControllerType` enum (steeringOnly / steering3Pedals / steering2Pedals / steeringDashboard / full) with `prefsKey`. Persist via `SharedPreferences`. Expose in `SettingsViewModel` with `selectControllerType()`. |  |  |
| TASK-018 | Add `PedalLayout` enum variants a-d (TASK-012 description). Persist similarly. Drives `PedalPanel` build: conditional `Visibility` + `Row` order mapping. |  |  |
| TASK-019 | Rebuild `SettingsScreen` (settings_screen.dart:56) with M3: `SegmentedButton` for keyboard/gamepad, `ListTile` + `Radio` for controller type, `DropdownMenu` or `SegmentedButton` for layout. Per-control mapping list: `ListTile(title: ControlId.label, trailing: KeyCode/ButtonId chip)` with tap → `Dialog` to rebind (listen to `RawKeyboard` or gamepad). Put advanced rebinding behind `ExpansionTile`. |  |  |
| TASK-020 | Add "Reset to default" `OutlinedButton` + `AlertDialog` confirm. Calls `SettingsRepository.reset()` + `viewModel.select(defaultMapping)` + reset `ControllerType`/`PedalLayout`. Show `SnackBar` "Reset to defaults". |  |  |

### Phase 4 — About + Donate

- **GOAL-005**: About & Donate screens

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-021 | Build `AboutScreen` — M3 `ListView`: developer row (avatar `CircleAvatar` + name Fazri Gading + subtitle), `ListTile` source code (`Icons.code` → `https://github.com/fazrigading/WheelDeck`), GitHub Stars row: fetch star count via `http` or `url_launcher` + `shields.io` badge (`https://img.shields.io/github/stars/fazrigading/WheelDeck`). Cache count, handle offline. |  |  |
| TASK-022 | Build `DonateScreen` — M3 `Card` list for 3 links: BuyMeACoffee, PayPal, Ko-fi with `Icons.favorite`/`Icons.coffee`. Each `ListTile` opens via `url_launcher` `launchUrlString`. Add `FilledTonalButton` "Support the project". |  |  |
| TASK-023 | Add `url_launcher: ^6.x` to `mobile/pubspec.yaml` (currently absent). Also add `http: ^1.x` if fetching stars via API. |  |  |

### Phase 5 — Polish & QA

- **GOAL-006**: M3 polish, a11y, states, tests

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-024 | Audit all screens for M3: 8pt grid (`16,24,32`), `rounded-2xl` cards (`BorderRadius 16-24`), soft tinted shadows, `44x44` tap targets, typography max 4 sizes/2 weights, color 60/30/10 rule, contrast ≥ 4.5:1. Add `AppBar.centerTitle`, `NavigationBar` if bottom nav needed. |  |  |
| TASK-025 | Add empty/loading/error/success states for Connect discovery (currently `_EmptyState` plain text) — M3 illustration + guidance + CTA per skill "Turn empty states into opportunities". |  |  |
| TASK-026 | Peak-End polish: success micro-animation on connected (sparkle/bounce via `AnimatedContainer`), summary at disconnect, haptics on recalibration. |  |  |
| TASK-027 | Widget tests: `connection_screen_test` (FAB opens sheet, IP filter, PIN visible), `lifecycle_observer_test` (inactive ≠ pause), `settings_view_model_test` (preset/layout/reset). |  |  |
| TASK-028 | Manual QA: Android notification shade → resume stays connected; gyro drift → recalibrate zeroes; paired device persists after kill. |  |  |

## 3. Alternatives

- **ALT-001** Add `go_router` for Menu routing — rejected for now; `Navigator` suffices, add only if deep links needed.
- **ALT-002** Use `flutter_secure_storage` for paired tokens — overkill; `SharedPreferences` enough, token already via `SharedPreferencesSessionTokenStore`.
- **ALT-003** Make recalibration auto-trigger on shake gesture — rejected; explicit button is intentional (M3) and avoids false triggers while driving.
- **ALT-004** Custom M3 theme generator (Material Theme Builder) vs hand-coded `ColorScheme.fromSeed` — start with `fromSeed`, import generated `theme.dart` only if brand palette finalized.

## 4. Dependencies

- **DEP-001** `url_launcher` — Donate + About external links (not yet in pubspec.yaml:9)
- **DEP-002** `http` — optional GitHub stars count fetch (or use shields.io image without fetch)
- **DEP-003** Existing `SharedPreferences`, `provider`, `permission_handler` — already present
- **DEP-004** `FilteringTextInputFormatter` — in `flutter/services.dart`, no new dep

## 5. Files

- **FILE-001** `mobile/lib/main.dart` — M3 theme + Menu routing insertion
- **FILE-002** `mobile/lib/ui/core/theme/app_theme.dart` — new `ColorScheme`/`TextTheme` tokens
- **FILE-003** `mobile/lib/ui/features/menu/views/menu_screen.dart` — new Menu hub
- **FILE-004** `mobile/lib/ui/features/connection/views/connection_screen.dart` — status card, paired split, FAB modal, input formatters, PIN fix
- **FILE-005** `mobile/lib/ui/features/connection/views/manual_add_sheet.dart` — new bottom sheet form
- **FILE-006** `mobile/lib/ui/features/connection/view_models/connection_view_model.dart` — paired split getters
- **FILE-007** `mobile/lib/data/repositories/paired_device_repository.dart` — new paired persistence
- **FILE-008** `mobile/lib/ui/core/lifecycle_observer.dart` — inactive vs paused fix
- **FILE-009** `mobile/lib/ui/features/driving/views/driving_view.dart` — recalibration button
- **FILE-010** `mobile/lib/ui/features/driving/view_models/driving_view_model.dart` — `recalibrate()`
- **FILE-011** `mobile/lib/data/services/input_mapping.dart` — presets
- **FILE-012** `mobile/lib/data/repositories/settings_repository.dart` + `ui/features/settings/view_models/settings_view_model.dart` + `views/settings_screen.dart` — controller type/layout/reset
- **FILE-013** `mobile/lib/ui/features/driving/views/pedal_panel.dart` — layout variants
- **FILE-014** `mobile/lib/ui/features/about/views/about_screen.dart` — new
- **FILE-015** `mobile/lib/ui/features/donate/views/donate_screen.dart` — new
- **FILE-016** `mobile/pubspec.yaml` — `url_launcher`, `http`
- **FILE-017** `TODO.md` — mark tasks complete per phase

## 6. Testing

- **TEST-001** Unit: `PairedDeviceRepository` save/load paired list.
- **TEST-002** Unit: `LifecycleObserver` — `inactive` does not call `pause()`, `paused` does.
- **TEST-003** Widget: Connect FAB opens `ManualAddSheet`; IP field rejects letters; PIN field `obscureText == false`.
- **TEST-004** Widget: Recalibration button calls `setCenter()` even when `awaitingCalibration == false`.
- **TEST-005** Widget: Settings reset restores defaults and shows SnackBar.
- **TEST-006** Manual: Android — open notification shade during driving, swipe back, verify still connected (or auto-reconnected without calibration gate if was only `inactive`).
- **TEST-007** Manual: iOS — same lifecycle check.
- **TEST-008** Manual: Donate links open externally; About stars badge renders.

## 7. Risks & Assumptions

- **RISK-001** Notification shade behavior varies by OEM — `inactive` vs `paused` split may not cover all devices. Mitigation: debounce timer + manual QA on 2-3 devices; fallback is existing `CalibrationOverlay` reconnect flow.
- **RISK-002** Paired persistence keyed on `host:port` may duplicate if DHCP changes IP. Mitigation: key on `DiscoveredServer.name` + `host`; or store `deviceId` if protocol exposes it.
- **RISK-003** GitHub stars API rate-limits unauthenticated (60/hr). Mitigation: use shields.io badge image (no API call) or cache with 1-day TTL.
- **ASSUMPTION-001** Branch `feature/revamp-mobile-ui` is green on `mobile-ci.yml` before merge.
- **ASSUMPTION-002** No desktop changes needed — ETS2 preset values already in `desktop/WheelDeck.Core/Input/InputMapper.cs:13`.

## 8. Related Specifications / Further Reading

- `TODO.md` — source of revamp tasks
- `docs/project-structure.md` — repo layout & layer naming
- `mobile/lib/ui/features/connection/views/connection_screen.dart` — current Connect UI
- `mobile/lib/ui/features/driving/views/driving_view.dart` — current Driving + lifecycle
- `mobile/lib/ui/core/lifecycle_observer.dart` — pause/resume logic
- `~/.agents/skills/mobile-app-ui-design/references/industry-conventions.md` — M3 + Peak-End guidance
- Material Design 3 — https://m3.material.io/
- `plan/feature-unified-connection-flow-1.md` — prior connection flow plan template
