---
goal: Revamp dashboard controls for ETS2 — light cycle, blink, 27+ new controls, layouts per steering mode
version: 1.0
date_created: 2026-09-12
last_updated: 2026-09-12
owner: fazrigading
status: Draft
tags:
  - feature
  - mobile
  - desktop
  - dashboard
  - ets2
---

# Introduction

![Status: Draft](https://img.shields.io/badge/status-Draft-yellow)

Branch `feature/revamp-dashboard` off `main`, after `feature/rotatable-steering-mode` lands. Visual references: `plan/references/` (SimDashboard truck A OFF/ON, B compact/full).

Glossary: **Light cycle** (OFF → Parking → Low, phone-held, High-beam independent), **Hazard** (both signals ~1.5Hz, suppresses L/R), **Tilt readout** (X-axis line), **Unbound control** (empty keybind → phone sends nothing), **Engine start mode** (hold-confirm vs single press), **Pedal side**, **Controller visibility**.

## 1. Requirements & Constraints

- **REQ-001 Lights**: One headlight control cycling OFF → Parking → Low → OFF with 3 visuals. Phone holds state; wire `lights_parking` / `lights_lowbeam` / `lights_off`, all three pulse `L` on desktop (ETS2 cycles natively). High-beam independent (`K`).
- **REQ-002 Signals**: L/R arrows blink ~1.5Hz. Phone holds L/R/Hazard state. Hazard drives both visuals, suppresses individual toggles until cleared. Grid never shows L/R: rotatable → arrows above wheel; gyro → arrows above left pedal.
- **REQ-003 Gyro layout**: Dashboard OFF → wheel middle + tilt readout under. Dashboard ON → wheel dropped, tilt readout only at top-center, dashboard in remaining space. Pedals at per-pedal sides.
- **REQ-004 Rotatable layout**: Wheel bottom-left, 50% device width. Signals above wheel (replace grid L/R). Accel+Brake bottom-right. Clutch (if shown) top-left above signals. Gear Up/Down (if shown) vertical top-right above pedals. Remaining ~20 controls: scrollable compact grid, center-right.
- **REQ-005 Size**: 64px circles, 8px gap. Rounded-rectangle fallback if grid still overflows small phones.
- **REQ-006 Existing fixes**: Cruise Toggle `C` (verify — already `C` both sides, no-op if confirmed). "Cruise set/resume" → rename "Cruise Resume", user-set-able. "HI/Hl" → "High-beam", `K` (verify — already `K`, no-op if confirmed). Shrink all buttons per REQ-005.
- **REQ-007 New buttons** (fixed default keys): Hazard `F`, Beacon `O`, Flasher `J`, Horn in grid `H` (not wheel center), Trailer `T`, Lift/Drop Axle `U`, Camera top-row Digit9 (not numpad).
- **REQ-008 Actions**: Toggle-pulse: Hazard, Beacon, Trailer, Axle, Engine Brake. Momentary press-release: Horn, Flasher, Gear Up/Down, Retarder ±, Camera, Quick Info, Mirror, HUD, Vehicle Adj, Nav Zoom, Widget Opt, Services, Quick Save/Load, Screenshot, Garage, Audio/Radio. Engine Start keeps hold/press mode.
- **REQ-009 b.1 Settings toggles** (M3): per-pedal Left/Right; Engine Start hold-vs-press; Gear Up (`Left Shift`), Gear Down (`Left Ctrl`), Engine Brake `B`, Air Horn `N`, Diff Lock `V`, Retarder+ `;`, Retarder− `'`, Quick Info `F1`, Mirror `F2`, HUD `F3`, Vehicle Adj `F4`, Nav Zoom `F5`, Widget Opt `F6`, Services `F7`, Quick Save `Scroll Lock`, Quick Load `Pause`, Screenshot `F10`, Garage `G`, Audio `R`. Visibility defaults: Gear Up/Down + Engine Brake ON, rest OFF.
- **REQ-010 b.2 empty keybinds**: Drive / Reverse / Neutral, Engine Electricity, ACC Mode, CC ±, Lane Mode, Lane Keeping, Emergency Brake, Wipers Back, Audio Play/Pause/Next/Prev/Vol±/Fav — all default empty. Phone sends nothing when per-mode binding empty (both modes); gamepad defaults empty too. Desktop ignores unknown `ControlId` as safety net.
- **REQ-011 Authority**: Phone gates sending (universal, all controls, both modes). Desktop `InputMapper` tables stay total: key row for every new `ControlId` (TODO defaults) + gamepad row on spare buttons. `AllControlIds_Have{Key,Button}Bindings` stays green.
- **REQ-012 KeyCode expansion** (desktop, required): F1–F10, Digit0–9, `LeftShift`, `LeftCtrl`, `Semicolon`, `Quote`, `ScrollLock`, `Pause` + VK codes (`SendInputKeySimulator`) + evdev codes (`UinputBackend`). `;`/`'` assume US layout.
- **REQ-013 Shown-but-unbound**: Visible button with empty keybind renders disabled with "—" chip; tap opens `_editBinding` binder. No silent inert buttons.
- **REQ-014 Horn**: In dashboard grid only. Wheel-center tap idea discarded (drag conflict).
- **CON-001**: Phone sends `ControlId` only, never key strings (existing protocol). All keybinds user-editable via existing `_editBinding` dialog; TODO keys are defaults.
- **CON-002**: Desktop stays stateless (lights/signal state on phone).

## 2. Implementation Steps

### Phase 0 — Desktop `KeyCode` expansion (unblocks everything)

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-001 | Extend `WheelDeck.Core/Output/KeyCode.cs`: F1–F10, Digit0–9, LeftShift, LeftCtrl, Semicolon, Quote, ScrollLock, Pause. Add VK map (`Backends/Windows/SendInputKeySimulator.cs`) + evdev map (`Backends/Linux/UinputBackend.cs`). `dotnet build` + manual key check per OS. |  |  |

### Phase 1 — Protocol + mapper

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-002 | Phone `ControlId` additions (`mobile/lib/data/services/dashboard_input.dart`): hazard/beacon/flasher/horn/trailer/axle/camera + REQ-009 set + REQ-010 set (snake_case wire names). Action per REQ-008. |  |  |
| TASK-003 | Desktop `ControlId` + `InputMapper` key rows (TODO defaults) + gamepad spare-button rows (`WheelDeck.Core/Input/InputMapper.cs`). Extend `InputMapperTests` (total-binding tests stay green). `dotnet test` green. |  |  |
| TASK-004 | Phone gating (`connection_repository`/`wheelddeck_client` send path): skip `sendButtonEvent` when per-mode binding empty. Lights 3-ID cycle + L-pulse; Hazard/L/R state + 1.5Hz blink. `flutter test` green. |  |  |
| TASK-005 | Phone presets (`controller_preset.dart`): ETS2 keyboard/gamepad rows for all new IDs; generic mirrors ETS2; b.2 empty in both modes. |  |  |

### Phase 2 — Dashboard UI + layouts

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-006 | Grid: 64px circles (rounded-rect fallback), `DashboardPanel` rework; L/R removed from grid; blink visuals for arrows + Hazard; disabled "—" state for unbound (tap → binder). Check against `plan/references/`. |  |  |
| TASK-007 | Gyro layouts (`driving_view.dart`): dash-OFF wheel middle + tilt line; dash-ON tilt readout top-center only; L/R arrows above left pedal; pedals per-pedal sides. |  |  |
| TASK-008 | Rotatable layouts: wheel bottom-left 50%; signals above wheel; pedals bottom-right; clutch top-left; gears vertical top-right; rest scrollable center-right grid. |  |  |
| TASK-009 | Settings page (M3): per-pedal Left/Right, Engine hold/press, REQ-009 toggles with defaults (gears + engine brake ON), binder dialog for all keybinds. |  |  |

### Phase 3 — Fixes + verify

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-010 | REQ-006: verify C/K no-ops, rename Cruise Resume + High-beam, set-able wiring, button shrink. `flutter test` + `dotnet test` green. Manual: full drive-through gyro + rotatable, lights cycle, hazard, unbound chip, small-phone fit. |  |  |

## Out of scope / deferred

- Rotatable wheel mechanics (prior branch). Non-ETS2 presets beyond generic mirror. Non-US layout key variants.

## Assumptions

1. Camera = top-row Digit9. 2. `;`/`'` US layout. 3. Spare gamepad buttons proposed at implementation (Back, DPadUp/Down, spare bumpers…). 4. 1.5Hz blink matches ETS2.
