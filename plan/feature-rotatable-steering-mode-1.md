---
goal: Rotatable finger-drag steering mode for phone + desktop test monitor, replacing ControllerType/PedalLayout enums
version: 1.0
date_created: 2026-09-12
last_updated: 2026-09-12
owner: fazrigading
status: Draft
tags:
  - feature
  - mobile
  - desktop
  - steering
---

# Introduction

![Status: Draft](https://img.shields.io/badge/status-Draft-yellow)

Branch `feature/rotatable-steering-mode` off `main`. Wire protocol unchanged: phone keeps sending `state.steering -1..1`; degree mapping lives phone-side. Desktop `InputMapper` untouched for steering. Dashboard revamp is separate (`feature-revamp-dashboard`).

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
| TASK-001 | Replace `ControllerType` enum (`mobile/lib/data/services/controller_type.dart`) with `showClutch/showDashboard` bools. `SettingsRepository`: new keys, first-run migration per table, delete `wheeldeck.controller_type` after. `SettingsScreen`: two M3 switches instead of 5-way radio. |  |  |
| TASK-002 | Replace `PedalLayout` A–D (`mobile/lib/data/services/pedal_layout.dart`) with per-pedal side map. Keys `wheeldeck.pedal_side.<pedal>`, migration per table, delete `wheeldeck.pedal_layout`. Settings: per shown pedal a Left/Right segmented control. |  |  |
| TASK-003 | Add wheel mode + degree. New or extended service (e.g. `wheel_mode.dart`): `Rotatable/Gyro`, degrees list, keys `wheeldeck.wheel_mode` / `wheeldeck.rotation_degree`, ETS2 default 900. `SettingsScreen`: mode toggle + degree selector under it. Fresh defaults: Rotatable 900°, Clutch OFF, Dashboard ON. |  |  |
| TASK-004 | `flutter test` green; manual: fresh install defaults + migrated install (seed old prefs, verify mapping, old keys gone). |  |  |

### Phase 2 — Rotatable wheel (mobile)

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-005 | New `RotatableWheel` widget (under `mobile/lib/ui/features/driving/views/`): circular drag → angle → `steering = clamp(angle / (degrees/2))`; spring-back to 0 on release; rotation indicator (rotating graphic + arc above ring). Multi-touch safe vs `PedalPanel`. |  |  |
| TASK-006 | `DrivingView`/`DrivingViewModel` branch: rotatable shows wheel, skips calibration gate + lifecycle reconfirm; gyro path untouched. Degree reload on Settings pop (same pattern as `refreshSettings`). |  |  |
| TASK-007 | Widget test: drag N/2° → full lock, release → 0; manual multi-touch steer + pedal. |  |  |

### Phase 3 — Desktop monitor widget

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-008 | `Views/SettingsView.axaml` + `ViewModels/SettingsViewModel.cs`: "Show wheel monitor" toggle button revealing display-only wheel mirror (arc + needle from live `steering`). Feed from `CompositionRoot` state events. No output driving. |  |  |
| TASK-009 | `dotnet build` + `dotnet test` green; manual: drag phone wheel, desktop mirror follows; toggle hides widget. |  |  |

## Out of scope / deferred

- All dashboard buttons/layouts (separate `feature-revamp-dashboard` plan).
- Draggable desktop widget driving output.
- Per-game degree memory beyond current preset key.

## Assumptions

1. Spelling canonical `Rotatable` (branch uses corrected spelling). 2. Generic preset also defaults 900° unless stated. 3. No desktop steering-output changes needed.
