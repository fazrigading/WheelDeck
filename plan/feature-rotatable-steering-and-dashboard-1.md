---
goal: Rotatable finger-drag steering + ETS2 dashboard revamp for phone, with desktop test monitor and key tables
version: 1.0
date_created: 2026-09-12
last_updated: 2026-09-14
owner: fazrigading
status: Finished
tags:
  - feature
  - mobile
  - desktop
  - steering
  - dashboard
  - ets2
---

# Introduction

![Status: Finished](https://img.shields.io/badge/status-Finished-green)

Branch `feature/rotatable-steering-and-dashboard` off `main`. Wire protocol unchanged: phone keeps sending `state.steering -1..1`; degree mapping lives phone-side. Desktop `InputMapper` untouched for steering. The ETS2 dashboard revamp landed on the same branch and is tracked below as phases 4-6 (single combined plan).

Glossary (see `CONTEXT.md`): **Rotatable steering** (finger-drag circular wheel, N° = full lock-to-lock), **Rotation degree** (180/270/900/1080/1800/2520, ETS2 default 900, gyro unaffected), **Rotation indicator** (rotating graphic + arc above ring), **Controller visibility** (show/hide Clutch + Dashboard only), **Pedal side** (per-pedal Left/Right), **Tilt readout** (X-axis line under gyro wheel).

## 1. Requirements & Constraints

- **REQ-001 Wire unchanged**: `state` message keeps `steering -1..1`. If current system state already sufficient, don't touch backend (TODO line 9). Degree → steering mapping is phone-side.
- **REQ-002 Wheel mode**: Settings toggle `Rotatable | Gyro`, persisted `wheeldeck.wheel_mode`. Fresh default Rotatable. Gyro path (tilt, calibration, reconfirm) unchanged.
- **REQ-003 Degrees**: Selectable 180 / 270 / 900 / 1080 / 1800 / 2520, persisted `wheeldeck.rotation_degree` per preset. ETS2 default 900. Gyro ignores degrees.
- **REQ-004 Visibility replaces enum**: Delete 5-way `ControllerType`; two booleans `showClutch` (`wheeldeck.show_clutch`, default OFF) + `showDashboard` (`wheeldeck.show_dashboard`, default ON). Wheel/Accel/Brake always shown. Migrate old values then delete old key.
- **REQ-005 Sides replace layout**: Delete `PedalLayout` A–D; per-pedal side map Acc/Brake/Clutch → Left/Right (`wheeldeck.pedal_side.<pedal>`). Fresh defaults Acc-R / Brake-R / Clutch-L. Migrate old values then delete old key.
- **REQ-006 Touch physics**: Release springs back to 0. Rotatable skips calibration gate + resume-reconfirm. Multi-touch: steer-drag + pedal-press concurrently (separate gesture arenas).
- **REQ-007 Rotation indicator**: Rotating wheel graphic + arc above ring (+ degree readout). Needs 1:1 drag feedback.
- **REQ-008 Desktop monitor**: Settings-view button-gated ("Show wheel monitor") display-only mirror of live `steering` with degree arc. No output driving. Reuse existing session/state events; no new infra.
- **CON-001**: Keep MVVM (`SettingsViewModel` owns state, `ListenableBuilder` views). No new nav packages.
- **PAT-001**: Persistence via `SettingsRepository` + `SharedPreferences`, same pattern as `InputMapping`.

### Migration table (Q26, verbatim)

| Old `ControllerType` | `showClutch` | `showDashboard` |
|---|---|---|
| steeringOnly | OFF | OFF |
| steering3Pedals | ON | OFF |
| steering2Pedals | OFF | OFF |
| steeringDashboard | OFF | ON |
| full | ON | ON |

| Old `PedalLayout` | Acc | Brake | Clutch |
|---|---|---|---|
| A | R | R | L |
| B | R | L | L |
| C | R | R | — |
| D | R | L | — |

## 2. Implementation Steps

### Phase 1 — Settings model + migration

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-001 | Replace `ControllerType` enum (`mobile/lib/data/services/controller_type.dart`) with `showClutch/showDashboard` bools. `SettingsRepository`: new keys, first-run migration per table, delete `wheeldeck.controller_type` after. `SettingsScreen`: two M3 switches instead of 5-way radio. | x | 2026-09-14 |
| TASK-002 | Replace `PedalLayout` A–D (`mobile/lib/data/services/pedal_layout.dart`) with per-pedal side map. Keys `wheeldeck.pedal_side.<pedal>`, migration per table, delete `wheeldeck.pedal_layout`. Settings: per shown pedal a Left/Right segmented control. | x | 2026-09-14 |
| TASK-003 | Add wheel mode + degree. New or extended service (e.g. `wheel_mode.dart`): `Rotatable/Gyro`, degrees list, keys `wheeldeck.wheel_mode` / `wheeldeck.rotation_degree`, ETS2 default 900. `SettingsScreen`: mode toggle + degree selector under it. Fresh defaults: Rotatable 900°, Clutch OFF, Dashboard ON. | x | 2026-09-14 |
| TASK-004 | `flutter test` green; manual: fresh install defaults + migrated install (seed old prefs, verify mapping, old keys gone). | x | 2026-09-14 |

### Phase 2 — Rotatable wheel (mobile)

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-005 | New `RotatableWheel` widget (under `mobile/lib/ui/features/driving/views/`): circular drag → angle → `steering = clamp(angle / (degrees/2))`; spring-back to 0 on release; rotation indicator (rotating graphic + arc above ring). Multi-touch safe vs `PedalPanel`. | x | 2026-09-14 |
| TASK-006 | `DrivingView`/`DrivingViewModel` branch: rotatable shows wheel, skips calibration gate + lifecycle reconfirm; gyro path untouched. Degree reload on Settings pop (same pattern as `refreshSettings`). | x | 2026-09-14 |
| TASK-007 | Widget test: drag N/2° → full lock, release → 0; manual multi-touch steer + pedal. | x | 2026-09-14 |

### Phase 3 — Desktop monitor widget

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-008 | `Views/SettingsView.axaml` + `ViewModels/SettingsViewModel.cs`: "Show wheel monitor" toggle button revealing display-only wheel mirror (arc + needle from live `steering`). Feed from `CompositionRoot` state events. No output driving. | x | 2026-09-14 |
| TASK-009 | `dotnet build` + `dotnet test` green; manual: drag phone wheel, desktop mirror follows; toggle hides widget. | x | 2026-09-14 |

## Out of scope / deferred

- Draggable desktop widget driving output.
- Per-game degree memory beyond current preset key.

## 3. Dashboard requirements & constraints

Visual references: `plan/references/` (SimDashboard truck A OFF/ON, B compact/full).

Glossary: **Light cycle** (OFF → Parking → Low, phone-held, High-beam independent), **Hazard** (both signals ~1.5Hz, suppresses L/R), **Tilt readout** (X-axis line), **Unbound control** (empty keybind → phone sends nothing), **Engine start mode** (hold-confirm vs single press), **Pedal side**, **Controller visibility**.

- **REQ-101 Lights**: One headlight control cycling OFF → Parking → Low → OFF with 3 visuals. Phone holds state; wire `lights_parking` / `lights_lowbeam` / `lights_off`, all three pulse `L` on desktop (ETS2 cycles natively). High-beam independent (`K`).
- **REQ-102 Signals**: L/R arrows blink ~1.5Hz. Phone holds L/R/Hazard state. Hazard drives both visuals, suppresses individual toggles until cleared. Grid never shows L/R: rotatable → arrows above wheel; gyro → arrows above left pedal.
- **REQ-103 Gyro layout**: Dashboard OFF → wheel middle + tilt readout under. Dashboard ON → wheel dropped, tilt readout only at top-center, dashboard in remaining space. Pedals at per-pedal sides.
- **REQ-104 Rotatable layout**: Wheel bottom-left, 50% device width. Signals above wheel (replace grid L/R). Accel+Brake bottom-right. Clutch (if shown) top-left above signals. Gear Up/Down (if shown) vertical top-right above pedals. Remaining ~20 controls: scrollable compact grid, center-right.
- **REQ-105 Size**: 64px circles, 8px gap. Rounded-rectangle fallback if grid still overflows small phones.
- **REQ-106 Existing fixes**: Cruise Toggle `C` (verify — already `C` both sides, no-op if confirmed). "Cruise set/resume" → rename "Cruise Resume", user-set-able. "HI/Hl" → "High-beam", `K` (verify — already `K`, no-op if confirmed). Shrink all buttons per REQ-105.
- **REQ-107 New buttons** (fixed default keys): Hazard `F`, Beacon `O`, Flasher `J`, Horn in grid `H` (not wheel center), Trailer `T`, Lift/Drop Axle `U`, Camera top-row Digit9 (not numpad).
- **REQ-108 Actions**: Toggle-pulse: Hazard, Beacon, Trailer, Axle, Engine Brake. Momentary press-release: Horn, Flasher, Gear Up/Down, Retarder ±, Camera, Quick Info, Mirror, HUD, Vehicle Adj, Nav Zoom, Widget Opt, Services, Quick Save/Load, Screenshot, Garage, Audio/Radio. Engine Start keeps hold/press mode.
- **REQ-109 b.1 Settings toggles** (M3): per-pedal Left/Right; Engine Start hold-vs-press; Gear Up (`Left Shift`), Gear Down (`Left Ctrl`), Engine Brake `B`, Air Horn `N`, Diff Lock `V`, Retarder+ `;`, Retarder− `'`, Quick Info `F1`, Mirror `F2`, HUD `F3`, Vehicle Adj `F4`, Nav Zoom `F5`, Widget Opt `F6`, Services `F7`, Quick Save `Scroll Lock`, Quick Load `Pause`, Screenshot `F10`, Garage `G`, Audio `R`. Visibility defaults: Gear Up/Down + Engine Brake ON, rest OFF.
- **REQ-110 b.2 empty keybinds**: Drive / Reverse / Neutral, Engine Electricity, ACC Mode, CC ±, Lane Mode, Lane Keeping, Emergency Brake, Wipers Back, Audio Play/Pause/Next/Prev/Vol±/Fav — all default empty. Phone sends nothing when per-mode binding empty (both modes); gamepad defaults empty too. Desktop ignores unknown `ControlId` as safety net.
- **REQ-111 Authority**: Phone gates sending (universal, all controls, both modes). Desktop `InputMapper` tables stay total: key row for every new `ControlId` (TODO defaults) + gamepad row on spare buttons. `AllControlIds_Have{Key,Button}Bindings` stays green.
- **REQ-112 KeyCode expansion** (desktop, required): F1–F10, Digit0–9, `LeftShift`, `LeftCtrl`, `Semicolon`, `Quote`, `ScrollLock`, `Pause` + VK codes (`SendInputKeySimulator`) + evdev codes (`UinputBackend`). `;`/`'` assume US layout.
- **REQ-113 Shown-but-unbound**: Visible button with empty keybind renders disabled with "—" chip; tap opens `_editBinding` binder. No silent inert buttons.
- **REQ-114 Horn**: In dashboard grid only. Wheel-center tap idea discarded (drag conflict).
- **CON-001**: Phone sends `ControlId` only, never key strings (existing protocol). All keybinds user-editable via existing `_editBinding` dialog; TODO keys are defaults.
- **CON-002**: Desktop stays stateless (lights/signal state on phone).

## 4. Dashboard implementation steps

### Phase 4 — Desktop `KeyCode` expansion (unblocks everything)

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-101 | Extend `WheelDeck.Core/Output/KeyCode.cs`: F1–F10, Digit0–9, LeftShift, LeftCtrl, Semicolon, Quote, ScrollLock, Pause. Add VK map (`Backends/Windows/SendInputKeySimulator.cs`) + evdev map (`Backends/Linux/UinputBackend.cs`). `dotnet build` + manual key check per OS. | x | 2026-09-14 |

### Phase 5 — Protocol + mapper

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-102 | Phone `ControlId` additions (`mobile/lib/data/services/dashboard_input.dart`): hazard/beacon/flasher/horn/trailer/axle/camera + REQ-109 set + REQ-110 set (snake_case wire names). Action per REQ-108. | x | 2026-09-14 |
| TASK-103 | Desktop `ControlId` + `InputMapper` key rows (TODO defaults) + gamepad spare-button rows (`WheelDeck.Core/Input/InputMapper.cs`). Extend `InputMapperTests` (total-binding tests stay green). `dotnet test` green. | x | 2026-09-14 |
| TASK-104 | Phone gating (`connection_repository`/`wheelddeck_client` send path): skip `sendButtonEvent` when per-mode binding empty. Lights 3-ID cycle + L-pulse; Hazard/L/R state + 1.5Hz blink. `flutter test` green. | x | 2026-09-14 |
| TASK-105 | Phone presets (`controller_preset.dart`): ETS2 keyboard/gamepad rows for all new IDs; generic mirrors ETS2; b.2 empty in both modes. | x | 2026-09-14 |

### Phase 6 — Dashboard UI + layouts

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-106 | Grid: 64px circles (rounded-rect fallback), `DashboardPanel` rework; L/R removed from grid; blink visuals for arrows + Hazard; disabled "—" state for unbound (tap → binder). Check against `plan/references/`. | x | 2026-09-14 |
| TASK-107 | Gyro layouts (`driving_view.dart`): dash-OFF wheel middle + tilt line; dash-ON tilt readout top-center only; L/R arrows above left pedal; pedals per-pedal sides. | x | 2026-09-14 |
| TASK-108 | Rotatable layouts: wheel bottom-left 50%; signals above wheel; pedals bottom-right; clutch top-left; gears vertical top-right; rest scrollable center-right grid. | x | 2026-09-14 |
| TASK-109 | Settings page (M3): per-pedal Left/Right, Engine hold/press, REQ-109 toggles with defaults (gears + engine brake ON), binder dialog for all keybinds. | x | 2026-09-14 |

### Phase 7 — Fixes + verify

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-110 | REQ-106: verify C/K no-ops, rename Cruise Resume + High-beam, set-able wiring, button shrink. `flutter test` + `dotnet test` green. Manual: full drive-through gyro + rotatable, lights cycle, hazard, unbound chip, small-phone fit. | x | 2026-09-14 |

## Out of scope / deferred

- Draggable desktop widget driving output.
- Per-game degree memory beyond current preset key.
- Non-ETS2 presets beyond generic mirror. Non-US layout key variants.

## Assumptions

1. Spelling canonical `Rotatable` (branch uses corrected spelling). 2. Generic preset also defaults 900° unless stated. 3. No desktop steering-output changes needed.
4. Camera = top-row Digit9. 5. `;`/`'` US layout. 6. Spare gamepad buttons proposed at implementation (Back, DPadUp/Down, spare bumpers…). 7. 1.5Hz blink matches ETS2.
