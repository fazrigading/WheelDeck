---
goal: Revamp the driving dashboard as a cell grid, fix fourteen reported defects, and ship the Sequential layout preset
version: 1.1
date_created: 2026-09-17
last_updated: 2026-09-17
owner: Fazri Gading
status: 'Planned'
tags: [feature, redesign, mobile, desktop, protocol]
---

# Introduction

![Status: In Progress](https://img.shields.io/badge/status-In%20Progress-yellow)

This plan rebuilds the mobile driving screen's rotatable layout as a cell grid
and resolves fourteen reported defects. The grid divides the landscape screen
into 2 rows x 3 columns of blocks, each block 4 rows x 5 columns of cells; cell
size follows the screen (`W/15 x H/8`) with no aspect guideline. The first
layout preset rendered by the grid is **Sequential**, which uses gear-up and
gear-down shifting.

Gyro mode keeps its current layout structure. Only its signal placement changes,
because signals stop being a bespoke widget.

Three follow-on phases expand the control and key enums so the preset's
remaining cells can be filled. Those phases are mechanical plumbing with no new
behaviour, except Phase 7, which adds the camera pad and its interaction mode.

This plan supersedes the design notes in `plan/plan-revamp-dashboard-v2.md`.
Deferred work — a user-editable layout, custom profiles, additional presets, and
camera control types beyond the D-pad — is recorded in
`plan/feature-custom-button-layout-1.md`.

### Revision note (v1.1)

A design review settled the geometry, the hazard model, and the binding story:
cells follow the screen with no aspect target; the wheel is horizontally
centered in its slot; hazard and turn signals are independent (REQ-021); the
camera pad encodes its input mode in the wire identifiers — thirteen controls
total (REQ-017, `docs/adr/0006-camera-pad-wire-identifiers.md`); gyro signals
render only in the pedal-column row (REQ-018); bindings are gamepad-first with
hybrid routing on the desktop and a keyboard fallback on the phone, and the
mapping default flips to gamepad (REQ-022 through REQ-026). Preset-scoped
desktop binding tables are deferred to `plan/feature-custom-button-layout-1.md`.

## 1. Requirements & Constraints

### Functional requirements

- **REQ-001**: The top bar (`AppBar`) is removed from the driving screen
  entirely. Recalibrate stays reachable via the existing floating action button.
- **REQ-002**: Every dashboard button is rectangular, not circular. A 1x1 cell
  is `W/15 x H/8`; its aspect follows the screen and no aspect guideline is
  imposed. Gear buttons are 2x2 cells.
- **REQ-003**: The rotatable steering wheel is sized from its block: diameter
  equals the block's pixel height (540 at 2400x1080), fits inside its 4x4-cell
  slot, horizontally centered with equal margins left and right (~50 device px
  per side at 2400x1080), flush with the slot's bottom edge, fully visible.
- **REQ-004**: Pedal height in rotatable mode is exactly half the screen height,
  anchored bottom-right, with a small inset inside each bar.
- **REQ-005**: The region between the wheel and the pedals renders dashboard
  items. Block E occupies this region; no additional widget is required.
- **REQ-006**: Turn-signal buttons use straight-arrow icons,
  `Icons.arrow_back` and `Icons.arrow_forward`.
- **REQ-007**: The rotatable wheel's spring-back to zero animates over
  approximately 700ms with an eased curve, instead of resetting instantly. A
  setting toggles the feature; when off, the wheel holds its released angle and
  steering remains at that value until the user drags it back. Default is on.
- **REQ-008**: Pedal labels `ACC`, `BRK`, and `CLT` are removed. Track colour is
  the pedal's hue at 25% alpha over the existing dark base; the pressure fill is
  the same hue at full opacity. Accelerator blue, brake red, clutch yellow.
- **REQ-009**: Turning one turn signal on while the other is on clears the other
  signal's blink **without sending the cleared signal's control event**. ETS2
  cancels the opposite signal itself, verified in game, so app and truck remain
  in sync.
- **REQ-010**: The `Pedal sides` settings section is shown only in gyro mode.
- **REQ-011**: The `Dashboard controls` settings section is shown only in gyro
  mode. In rotatable mode the `Clutch pedal` switch remains, and accelerator and
  brake are unconditional.
- **REQ-012**: In rotatable mode the accelerator pedal is the right-most of the
  two pedals.
- **REQ-013**: The wheel's progress arc spans 180 degrees across the top. The
  fill starts at twelve o'clock and grows toward the turned side, with length
  proportional to the absolute steering value. Zero steering fills nothing.
- **REQ-014**: Back navigation from the driving screen opens a confirmation
  dialog with three actions: **Settings** (push the settings screen and refresh
  on return), **Disconnect** (disconnect and land on app Home), **Stay**
  (dismiss). Disconnect no longer pushes the connection screen.
- **REQ-015**: The rotatable layout is defined as a 2x3 block grid, each block
  4 rows x 5 columns of cells, addressed as `block[row, col]` and
  `cell[row, col]`. The layout is declared as data in one file, not as nested
  widget literals.
- **REQ-016**: A layout preset supplies cell contents and default bindings for
  the Sequential shifting scheme. The preset is authoritative for placement in
  rotatable mode.
- **REQ-017**: Block C contains a 3x3 camera pad with eight directions and a
  center cell. The pad's input mode is encoded in the wire identifiers
  (`docs/adr/0006-camera-pad-wire-identifiers.md`): numpad mode sends
  `camera_pad_up`, `camera_pad_down`, `camera_pad_left`, `camera_pad_right`,
  `camera_pad_up_left`, `camera_pad_up_right`, `camera_pad_down_left`,
  `camera_pad_down_right`, which the desktop resolves to `Numpad7/8/9`,
  `Numpad4/6`, `Numpad1/2/3`, and `camera_pad_recenter` (`Numpad5`) on tap.
  Arrow mode sends `camera_pad_arrow_up`, `camera_pad_arrow_down`,
  `camera_pad_arrow_left`, `camera_pad_arrow_right`, which the desktop resolves
  to the arrow keys; the four diagonals are disabled and have no wire
  identifiers. The center cell switches input mode on a three-second hold.
  Arrow mode has no recenter key, so its center cell only switches back.
- **REQ-018**: Turn signals are ordinary grid entries rendered by
  `DashboardControl`, not a separate widget. Blink state is derived from the
  existing send-gate state. In gyro mode the signals render only in the
  pedal-column signal row, in both dashboard states;
  `DashboardPanel.coreEntries` is not extended with them.
- **REQ-019**: `showDashboard` is ignored in rotatable mode; blocks B, C, and E
  always render there.
- **REQ-020**: User binding overrides win over preset defaults. Switching
  presets must never discard a per-control override made in Settings.
- **REQ-021**: Hazard and the individual turn signals are independent. A signal
  tap while hazard is on sends normally and the signal cell blinks its own
  state; hazard is unaffected and keeps blinking. The former suppression branch
  is removed. Left/right mutual exclusion (REQ-009) is unchanged.
- **REQ-022**: Binding routing is hybrid. In gamepad mapping mode a control
  presses its virtual controller button when one is bound, otherwise its
  keyboard key; in keyboard mode the priority is reversed.
  `InputMapper.ApplyButton` treats the mapping mode as a route priority, not an
  exclusivity switch.
- **REQ-023**: In gamepad mode the phone's binding resolution falls back to the
  keyboard preset map for controls the gamepad map lacks, so the send gate, the
  Settings binder, and cell enabled-states agree with what the desktop fires.
- **REQ-024**: `InputMapping` defaults to `gamepad`; reset-to-defaults restores
  `gamepad`.
- **REQ-025**: The `mapping` frame gains `protocol/schema/mapping_message.json`,
  mirroring the existing message schemas.
- **REQ-026**: The Sequential preset's keyboard defaults are: audio row
  `L`/`J`/`K`/`U`/`O` (Vol-, Prev, Play/Pause, Next, Vol+); menu `Escape`, world
  map `M`, photo mode `EqualSign`, activate `Enter`; the remaining new-control
  keys per the original research (TASK-046). Still inert by design: adaptive
  cruise, lane keeping, lane assistant, cruise speed increase/decrease,
  emergency brake, shift to neutral, engine electricity.

### Constraints

- **CON-001**: A 1x1 cell is `W/15 x H/8`; its aspect follows the screen. No
  fixed 64-pixel control size survives.
- **CON-002**: Every `KeyCode` member requires a row in **both** backend tables:
  `SendInputKeySimulator.VirtualKeyCodes` and `UinputBackend.KeyCodes`.
  `desktop/WheelDeck.Tests/KeyCodeCoverageTests.cs` fails the build otherwise,
  because a missing row makes `SendKey` silently drop the key.
- **CON-003**: Every `ControlId` must exist in all three of mobile
  `ControlId`, desktop `ControlId`, and `protocol/schema/controls.json`.
  `desktop/WheelDeck.Tests/ControlIdContractTests.cs` and
  `mobile/test/data/services/control_contract_test.dart` both assert exact
  set-equality against the schema.
- **CON-004**: The gyro layout keeps its current structure: tilt readout
  top-center, pedals as full-height left and right columns, dashboard as a
  `Wrap` in the middle. It gains no block grid.
- **CON-005**: No new dependency is added to either `pubspec.yaml` or the
  desktop solution. The grid, the drag-hit-testing, and the tap-or-hold
  interaction all use `flutter/material.dart`.
- **CON-006**: The camera pad's input mode is encoded in the wire identifiers
  themselves (numpad set vs arrow set), so the shared send gate resolves them
  like any other control. The pad selects the mode-resolved `ControlId` before
  the event reaches the gate. See `docs/adr/0006-camera-pad-wire-identifiers.md`.

### Guidelines and patterns

- **GUD-001**: Follow the existing view-model pattern: a `ChangeNotifier` with
  immutable snapshot getters, rendered through `ListenableBuilder`, with the
  view delegating gestures to command methods. See
  `mobile/lib/ui/features/driving/view_models/driving_view_model.dart`.
- **GUD-002**: Every storage load and save is best-effort and never throws, so
  driving keeps working when storage is unavailable. See
  `DrivingViewModel.init` and `refreshSettings`.
- **GUD-003**: Changes are surgical. Do not refactor adjacent code, rename
  unrelated symbols, or reformat untouched regions.
- **PAT-001**: Persisted preferences are a small class with a `prefsKey`, a
  `fallback`, an `allowed` or default set where relevant, and static `load` plus
  instance `save` methods. Model on
  `mobile/lib/data/services/wheel_mode.dart`.
- **PAT-002**: Optional inputs are feature-detected by set membership
  (`visibleExtras.contains(control)`), not by nullable booleans. Model on
  `DashboardVisibility`.
- **PAT-003**: Tests are plain, framework-light, one behaviour per test, in the
  mirrored directory under `mobile/test/` or `desktop/WheelDeck.Tests/`.

### Performance requirements

- **PERF-001**: A steering update must not rebuild more than the wheel subtree.
  The grid renders once per preset load, not per steering frame.
- **PERF-002**: The camera pad's mode-switch hold timer is cancelled on release
  and on dispose; no timer outlives its widget.

## 2. Implementation Steps

### Implementation Phase 1

- GOAL-001: Land the shared widget changes: top bar removal, rectangular
  buttons, straight signal arrows, pedal colours, signal mutual exclusion, and
  the back-navigation dialog. These apply to both wheel modes.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-001 | In `mobile/lib/ui/features/driving/views/driving_view.dart`, delete the `appBar:` argument from the `Scaffold` in `_DrivingViewState.build` (currently lines 175-204). Remove the now-orphaned `recalibrate-button` `IconButton` and both `IconButton`s for settings and disconnect. Keep the `floatingActionButton` from REQ-001 and the existing `key: const Key('recalibrate-fab')`. | | |
| TASK-002 | In the same file, wrap the `Scaffold` in `PopScope(canPop: false, onPopInvokedWithResult: ...)`. Add `Future<void> _onExitRequested()` showing an `AlertDialog` titled `Exit driving mode?` with three actions: `Settings`, `Disconnect`, `Stay`. `Settings` pops the dialog, awaits `Navigator.push` of `SettingsScreen(coordinator: widget.coordinator)`, then awaits `_viewModel.refreshSettings()`. `Stay` pops the dialog with no action. Satisfies REQ-014. | | |
| TASK-003 | In the same file, implement the dialog's `Disconnect` action to pop the dialog, then `await _viewModel.disconnect()` and return. Delete the existing `_onDisconnect` method (currently lines 120-127) and its `Navigator.push` of `ConnectionScreen`. Remove the now-unused import of `connection_screen.dart` (line 18). `_Routing` in `mobile/lib/main.dart` flips to `MenuScreen` on disconnect, so no navigation call is needed. Satisfies REQ-014. | | |
| TASK-004 | In `mobile/lib/ui/features/driving/views/dashboard_panel.dart`, in `_DashboardControlState.build`, remove the `compact` local and the `shape: compact ? BoxShape.rectangle : BoxShape.circle` branch (currently lines 306-334). Use `shape: BoxShape.rectangle` unconditionally with `borderRadius: BorderRadius.circular(12)`. Satisfies REQ-002 for the grid path. | | |
| TASK-005 | In the same file, make no change to `DashboardPanel.coreEntries`/`coreControls` — the signals are bound directly by the rotatable grid's block A slots (TASK-015) and by the gyro signal row (TASK-029), so the shared `Wrap` must not render them a second time (REQ-018). Verify `DashboardControl.modeFor` maps both signal controls to `ControlMode.toggle` and leave as-is. Satisfies REQ-018. | | |
| TASK-006 | In the same file, extend `_DashboardControlState._active` so a turn-signal cell reads gate state. Add a branch mirroring the existing hazard branch: when `widget.control` is `turnSignalLeft` or `turnSignalRight` and `gate != null`, return `gate.signalVisualActive(widget.control)`. Extend `_gateDriven` and `_listened` to include the two signal controls so the listener subscribes and unsubscribes correctly. Satisfies REQ-018 and REQ-006's visual path. | | |
| TASK-007 | In the same file, add `IconData? iconFor(ControlId control)` as a static method on `DashboardPanel`, returning `Icons.arrow_back` for `turnSignalLeft` and `Icons.arrow_forward` for `turnSignalRight`, and `null` otherwise. In `_DashboardControlState.build`, render `Icon(icon, ...)` in place of the label `Text` when the resolver returns non-null, at the existing 11px-equivalent size scaled to the cell. Satisfies REQ-006. | | |
| TASK-008 | Delete `mobile/lib/ui/features/driving/views/signal_arrows.dart`. Remove the `_arrows` getter (currently `driving_view.dart:273-276`), its uses in `_rotatableLayout` and `_gyroLayout`, and the `import 'signal_arrows.dart'`. Satisfies REQ-018. Placement replacement is TASK-014 and TASK-024. | | |
| TASK-009 | In `mobile/lib/ui/features/driving/views/pedal_panel.dart`, delete the `label` field from `PedalBar`, the label `Text` widget and its `SizedBox(height: 6)` (currently lines 79-86), and the `label` argument at the `PedalPanel.build` call site. Satisfies REQ-008. | | |
| TASK-010 | In the same file, add a `Color _hue(PedalType pedal)` top-level or static resolver returning `0xFF1E88E5` for accelerator, `0xFFE53935` for brake, and `0xFFFDD835` for clutch. Change the track `Container` colour (currently `0xFF2A2A2A` at line 105) to the pedal hue with `withValues(alpha: 0.25)` composited over the existing dark base — implement as a `Stack` of the dark `0xFF2A2A2A` layer with the hue at 25% alpha above it. Change the fill `Container` colour (currently `0xFFE53935` at line 115) to the pedal hue at full opacity. Satisfies REQ-008. | | |
| TASK-011 | In `mobile/lib/data/services/dashboard_send_gate.dart`, in `handle`, delete the hazard-suppression branch (`if (_hazardOn) return;`, currently lines 106-109) so a signal tap during hazard sends normally. Keep the left/right mutual exclusion: when `turnSignalLeft` toggles to on, set `_rightOn = false` (and the reverse) without sending the cleared control's event. Call `_syncBlinkTimer()` after. Change `signalVisualActive` to own-state blink: left returns `_blinkOn && _leftOn`, right returns `_blinkOn && _rightOn`, hazard returns `_blinkOn && _hazardOn`. Satisfies REQ-009 and REQ-021. | | |
| TASK-012 | Add `mobile/test/ui/features/driving/signal_arrows_test.dart` coverage into `dashboard_panel_test.dart` as a new test group, then delete `signal_arrows_test.dart`. The ported assertions are: a signal cell with `gate` null renders inert; with an active gate it renders the straight-arrow icon and blinks its own state; it sends normally while hazard is on. Satisfies REQ-018 and REQ-021. | | |

### Implementation Phase 2

- GOAL-002: Introduce the layout data model and render the rotatable screen
  through it, resolving the wheel, pedal, and arc defects.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-013 | Create `mobile/lib/data/services/driving_layout.dart`. Define `class CellRect { final int rowStart, colStart, rowSpan, colSpan; }` with a `const` constructor and value equality. Define `class LayoutSlot { final CellRect rect; final ControlId? control; final SlotKind kind; }` where `SlotKind` is an enum of `button`, `pedal`, `wheel`, `gearUp`, `gearDown`, `cameraPad`, `hole`. Define `class DrivingLayout` holding `String name`, `List<LayoutSlot> slots`, and `ControlId? controlAt(CellRect)`. Satisfies REQ-015. | | |
| TASK-014 | In the same file, define `const List<CellRect> blocks` as the six block regions: A `(1,1,4,5)`, B `(1,6,4,5)`, C `(1,11,4,5)`, D `(5,1,4,5)`, E `(5,6,4,5)`, F `(5,11,4,5)`, using the `(rowStart, colStart, rowSpan, colSpan)` form against the global 8x15 grid. Satisfies REQ-015. | | |
| TASK-015 | In the same file, add `static DrivingLayout sequential()` returning the Sequential preset slots per the block tables in `plan/plan-revamp-dashboard-v2-original.md`: block A `G` adaptiveCruise, `H` laneKeeping, `I` laneAssistant, `L` trailerAxle, `M` liftDropAxle, `N` trailer, `Q` hazardLights, `R` beaconLights, `S` differentialLock, `V` turnSignalLeft, `W` turnSignalRight, `X` highBeamToggle, plus clutch at cols 4-5 rows 1-4; block B row 1 audioVolumeDown, audioPrevious, audioPlayPause, audioNext, audioVolumeUp (symbol icons at render time), row 2 driver_window_up, navigation_zoom_in, cruiseSpeedIncrease, retarderIncrease, passenger_window_up, row 3 driver_window_down, navigationZoomOut, cruiseSpeedDecrease, retarderDecrease, passenger_window_down, row 4 overlay_activation, chat_activation, quick_replies, name_tags, push_to_talk; block C gear up 2x2 at cols 1-2 rows 1-2, gear down 2x2 at cols 1-2 rows 3-4, camera pad 3x3 at cols 3-5 rows 1-3, row 4 emergencyBrake, engineBrake, cruiseToggle; block D wheel at cols 1-4 rows 1-4 plus horn, flasher, wipers, headlightToggle in column 5; block E rows 1-4 per the original table (camera_interior..camera_leanout; quickSave, dashboardInfo, nextCamera, hudWidgets, cruiseSetResume; quickInfo, mirrorToggle, screenshot, widgetOptions, services; menu, world_map, photo_mode, garageManager, activate); block F col 1 engineElectricity, engineStart, parkingBrake, shiftToNeutral, plus brake at cols 2-3 and accelerator at cols 4-5. Slots whose `ControlId` does not yet exist in the enum are emitted as `SlotKind.hole` with a `null` control. Satisfies REQ-015 and REQ-016. | | |
| TASK-016 | Create `mobile/lib/ui/features/driving/views/block_grid.dart`. Implement `class BlockGrid extends StatelessWidget` taking `DrivingLayout layout`, `DashboardInput input`, `String Function(ControlId) bindingFor`, `DashboardSendGate? gate`, `PedalInput pedalInput`, `Set<PedalType> shownPedals`, `ValueChanged<double> onSteering`, and `VoidCallback? onBindRequested`. Render with a single `LayoutBuilder` producing a `Stack` of `Positioned` children, one per slot, each positioned by `rect` scaled against `constraints`. Satisfies REQ-015. | | |
| TASK-017 | In the same file, build each `LayoutSlot` into a widget by `kind`: `button` and `hole` to a cell-sized `DashboardControl` (holes rendered disabled, matching the existing unbound visual), `pedal` to a `PedalBar` sized to its rect, `gearUp` / `gearDown` to a 2x2 `DashboardControl`, `cameraPad` to a placeholder `SizedBox` in Phase 2 (filled in TASK-059), and `wheel` to `RotatableWheel`. Satisfies REQ-015. | | |
| TASK-018 | In `driving_view.dart`, replace the body of `_rotatableLayout` (currently lines 280-382) with a single `BlockGrid` built from `DrivingLayout.sequential()`, the view model's input and gate, the visible pedals, and `_viewModel.setRotatableSteering`. Delete the now-orphaned `wheelSize` local, the `gears` local, the manual `Row`/`Expanded`/`Column` nesting, and the inline gear `DashboardControl` loop. Satisfies REQ-015 and REQ-005. | | |
| TASK-019 | In `block_grid.dart`, size the wheel from block D: diameter equals the block's pixel height, laid out as a square box horizontally centered in the wheel slot with equal margins and flush to the slot's bottom edge. Remove the `clamp(160.0, 480.0)` from `driving_view.dart` (currently line 287) as part of TASK-018's deletion. At 2400x1080 this yields a 540 diameter centered in the 640-wide slot. Satisfies REQ-003 and CON-001. | | |
| TASK-020 | In `block_grid.dart`, size each pedal bar to its slot rect, which is rows 5-8 — exactly half the screen height — with the pedals in block F anchored to the screen's bottom-right. Replace the fixed `width: 64` in `pedal_panel.dart` (line 76) with a width derived from the slot. Reduce the inter-pedal gap to a fixed 8-pixel inset inside each bar. Satisfies REQ-004. | | |
| TASK-021 | Verify accelerator is the right-most pedal in the Sequential preset: brake at block F cols 2-3, accelerator at cols 4-5. Assert this in a layout test rather than relying on the visual. Satisfies REQ-012. | | |
| TASK-022 | In `mobile/lib/ui/features/driving/views/rotatable_wheel.dart`, add a `springBack` bool parameter defaulting to `true` and a `Duration springBackDuration` defaulting to `const Duration(milliseconds: 700)`. In `_onPanEnd`, when `springBack` is true, animate `_accumulated` to zero over that duration with `Curves.easeOutCubic` and call `widget.onChanged(0.0)` on completion; when false, leave `_accumulated` unchanged and call `widget.onChanged(_steering)` so the held angle transmits. Satisfies REQ-007. | | |
| TASK-023 | In the same file, replace `AnimatedRotation`'s fixed 80ms duration (`:99`) with the animated value driven by TASK-022 so the visual and the reported steering stay coherent, and cancel any in-flight spring-back animation in `_onPanStart` and in `dispose`. Satisfies REQ-007 and PERF-002. | | |
| TASK-024 | In the same file, change `_RotationArcPainter.paint` (currently lines 134-151) so the fill starts at twelve o'clock and grows toward the turned side. Keep the track as the 180-degree arc from `math.pi` sweeping `math.pi`. Compute the fill start as `math.pi * 3 / 2` (twelve o'clock) and sweep `math.pi / 2 * signedSteering` where `signedSteering` carries the sign, so positive steering sweeps clockwise into the right half and negative sweeps counter-clockwise into the left half. Change the painter's parameter from `progress` (0..1) to `steering` (-1..1) and update `shouldRepaint` accordingly. Satisfies REQ-013. | | |
| TASK-025 | Create `mobile/lib/data/services/spring_back.dart` with `class SpringBack { static const String prefsKey = 'wheeldeck.spring_back'; static const bool fallback = true; static Future<bool> load(); Future<void> save(); }` following PAT-001, in its own file like `camera_pad_mode.dart`. Satisfies REQ-007. | | |
| TASK-026 | In `driving_view_model.dart`, add `bool _springBack = SpringBack.fallback`, a `springBack` getter, load it in `_loadWheelState` (currently lines 176-186), and pass it to `RotatableWheel` from `BlockGrid`. Satisfies REQ-007. | | |
| TASK-027 | In `mobile/lib/ui/features/settings/views/settings_screen.dart`, add a `SwitchListTile` titled `Rotate back to zero` inside the existing `if (_viewModel.wheelMode == WheelMode.rotatable)` block, bound to a new `selectSpringBack` method. In `settings_view_model.dart`, add the `_springBack` field, getter, loader in `init`, persistence method, and include it in `resetToDefaults`. Also add it to the reset-confirmation dialog's content string (currently line 59). Satisfies REQ-007. | | |
| TASK-028 | Create `mobile/test/data/services/driving_layout_test.dart` asserting: the six block rects do not overlap and cover the 8x15 grid; the Sequential preset's clutch occupies exactly cols 4-5 rows 1-4 of block A; accelerator is right-most in block F; the wheel's layout box is square with diameter equal to block D's pixel height, horizontally centered with equal margins and flush bottom at a 2400x1080 constraint; and every slot with a non-null control names a `ControlId` that exists in `ControlId.values`. Satisfies REQ-015, REQ-012, and REQ-003. | | |

### Implementation Phase 3

- GOAL-003: Restore signal placement in gyro mode after the widget deletion in
  Phase 1.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-029 | In `driving_view.dart`, replace the deleted `_arrows` getter with a private method `Widget _signalRow()` returning a `Row(mainAxisSize: MainAxisSize.min)` of two `DashboardControl`s for `turnSignalLeft` and `turnSignalRight`, each built with `mode: ControlMode.toggle`, the view model's gate, `enabled: !DashboardSendGate.isUnbound(_viewModel.bindingFor(c))`, and `onBindRequested: _openBinder`. Satisfies REQ-018 and CON-004. | | |
| TASK-030 | In the same file, substitute `_signalRow()` for both former `_arrows` uses inside `_gyroLayout` — the `arrows: true` branch of `pedalColumn` (currently lines 396-400) and the direct use at line 461. Do not alter any other positioning in `_gyroLayout`. Satisfies CON-004. | | |
| TASK-031 | In the same file, note that `_gyroLayout`'s `dashboardVisible == false` branch (currently lines 413-446) renders the signal row above the left pedal column, which is the intended location. No structural change beyond TASK-030. Verify by test in TASK-032. Satisfies REQ-018. | | |
| TASK-032 | Add to `mobile/test/ui/features/driving/driving_view_model_test.dart` or a new widget test: gyro layout with dashboard hidden renders exactly two signal cells; gyro layout with dashboard shown renders them in the same position; rotatable layout renders them as top-left block cells. Satisfies REQ-018 and CON-004. | | |

### Implementation Phase 4

- GOAL-004: Apply the Settings visibility gating by wheel mode.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-033 | In `settings_screen.dart`, wrap the `Pedal sides` section (currently lines 192-218) in `if (_viewModel.wheelMode == WheelMode.gyro)`. Satisfies REQ-010. | | |
| TASK-034 | In the same file, wrap the `Dashboard controls` section (currently lines 234-250) in the same gyro-only condition, and wrap the `Dashboard` `SwitchListTile` (currently lines 176-186) in the same condition, leaving the `Clutch pedal` `SwitchListTile` visible in both modes. Satisfies REQ-011. | | |
| TASK-035 | In `driving_view.dart`, remove the `showDashboard` read from `_buildDrivingContent` for the rotatable path so `showDashboard` cannot suppress blocks B, C, and E. The rotatable branch already ignores it; assert this in the test from TASK-032. Satisfies REQ-019. | | |

### Implementation Phase 5

- GOAL-005: Fill blocks A, D, and F. One new control identifier.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-036 | Add `trailer_axle` to `protocol/schema/controls.json` under `definitions.ControlId.enum`, appended after `audio_favorite`. Satisfies CON-003. | | |
| TASK-037 | Add `TrailerAxle` to `desktop/WheelDeck.Core/Protocol/ControlId.cs`, mobile `ControlId.trailerAxle('trailer_axle')` to `mobile/lib/data/services/dashboard_input.dart`, and a `_controlLabel` arm returning `Trailer axle` to `settings_screen.dart`. Run both contract tests. Satisfies CON-003. | | |
| TASK-038 | Register `trailerAxle` in `desktop/WheelDeck.Core/Input/InputMapper.cs` in **both** `DefaultKeyBindings` and `DefaultButtonBindings`. Use `KeyCode.T` for keyboard, matching the plan's note, and `ButtonId.None` for gamepad, matching the existing convention for extras a 15-button pad cannot cover. Satisfies CON-002 and CON-003. | | |
| TASK-039 | Add `trailerAxle` to `mobile/lib/data/services/controller_preset.dart` in `ets2Keyboard` as `'T'`. Do not add it to `ets2Gamepad`, matching the `'-'` convention for controls with no gamepad default. Satisfies REQ-020. | | |
| TASK-040 | In `driving_layout.dart`, change the `SlotKind.hole` placeholders in blocks A, D, and F whose control now exists to their real `ControlId`s. Blocks D and F contain no control of their own that needs a new identifier, so this task is limited to block A's trailer axle cell. Satisfies REQ-016. | | |

### Implementation Phase 6

- GOAL-006: Fill blocks B and E. Approximately twenty new control identifiers.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-041 | Append to `protocol/schema/controls.json`: `driver_window_up`, `driver_window_down`, `passenger_window_up`, `passenger_window_down`, `navigation_zoom_in`, `overlay_activation`, `chat_activation`, `quick_replies`, `name_tags`, `push_to_talk`. Satisfies CON-003. | | |
| TASK-042 | Append to `protocol/schema/controls.json`: `camera_interior`, `camera_chasing`, `camera_topdown`, `camera_roof`, `camera_leanout`, `dashboard_info`, `next_camera`, `menu`, `world_map`, `photo_mode`, `activate`. Satisfies CON-003. | | |
| TASK-043 | Add all twenty-one identifiers from TASK-041 and TASK-042 to desktop `ControlId.cs` and mobile `ControlId`, using camelCase identifiers and snake_case wire values. Add a `_controlLabel` arm for each in `settings_screen.dart`. Run both contract tests. Satisfies CON-003. | | |
| TASK-044 | Add the `KeyCode` members these controls need to `desktop/WheelDeck.Core/Output/KeyCode.cs`: `Tab`, `Comma`, `Dot`, `Slash`, `RightShift`, `RightCtrl`, `EqualSign` (menu resolves to the existing `Escape`, world map to `M`, activate to `Enter`; the camera keys reuse the existing `Digit1-5`/`Digit9`). Satisfies CON-002. | | |
| TASK-045 | Add a row for each new `KeyCode` from TASK-044 in `SendInputKeySimulator.VirtualKeyCodes` (Windows virtual-key codes; `EqualSign` is `VK_OEM_PLUS` 0xBB) and in `UinputBackend.KeyCodes` (Linux evdev codes; `EqualSign` is `KEY_EQUAL`). Verify `KeyCodeCoverageTests` passes. Satisfies CON-002. | | |
| TASK-046 | Register the twenty-one new controls in `InputMapper.DefaultKeyBindings`: driver_window_up RightShift, navigation_zoom_in Slash, driver_window_down RightCtrl, passenger_window_up Comma, passenger_window_down Dot, overlay_activation Tab, chat_activation Y, quick_replies Q, name_tags Z, push_to_talk X, camera_interior Digit1, camera_chasing Digit2, camera_topdown Digit3, camera_roof Digit4, camera_leanout Digit5, dashboard_info I, next_camera Digit9, menu Escape, world_map M, photo_mode EqualSign, activate Enter. Also give the five audio controls their Sequential-preset keys (audioVolumeDown L, audioPrevious J, audioPlayPause K, audioNext U, audioVolumeUp O), replacing their current `KeyCode.None`. Register all twenty-one in `DefaultButtonBindings` with `ButtonId.None` (no gamepad equivalents). Satisfies CON-002, REQ-022, and REQ-026. | | |
| TASK-047 | Add the matching keyboard entries to `controller_preset.dart`'s `ets2Keyboard` map for all twenty-one controls (same keys as TASK-046) plus the five audio entries `L/J/K/U/O`. No `ets2Gamepad` additions. Satisfies REQ-020 and REQ-023. | | |
| TASK-048 | In `driving_layout.dart`, replace the remaining `SlotKind.hole` placeholders in blocks B and E with their real `ControlId`s. Satisfies REQ-016. | | |
| TASK-049 | Add the total new controls to `DashboardVisibility.toggleable` only if they should be user-toggleable in gyro mode. Decision rule: controls that make sense in a plain grid go in; camera and menu controls do not. Record which ones were added as a comment beside the list. Satisfies REQ-011. | | |

### Implementation Phase 7

- GOAL-007: Add the camera pad, its two input modes, and the tap-or-hold
  interaction. This is the only phase with non-mechanical work.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-050 | Append to `protocol/schema/controls.json`: `camera_pad_up`, `camera_pad_down`, `camera_pad_left`, `camera_pad_right`, `camera_pad_up_left`, `camera_pad_up_right`, `camera_pad_down_left`, `camera_pad_down_right`, `camera_pad_recenter`, `camera_pad_arrow_up`, `camera_pad_arrow_down`, `camera_pad_arrow_left`, `camera_pad_arrow_right` — thirteen identifiers for the pad. Satisfies CON-003 and REQ-017. | | |
| TASK-051 | Add the thirteen identifiers to desktop `ControlId.cs` and mobile `ControlId`, plus a `_controlLabel` arm each. Run both contract tests. Satisfies CON-003. | | |
| TASK-052 | Add the `KeyCode` members `Numpad1` through `Numpad9`, plus `ArrowUp`, `ArrowDown`, `ArrowLeft`, `ArrowRight`, to `KeyCode.cs`. Satisfies CON-002. | | |
| TASK-053 | Add a row for each new `KeyCode` from TASK-052 in both backend tables. The Windows table needs the VK_NUMPAD1-9 values (0x61-0x69) and VK_LEFT/UP/RIGHT/DOWN (0x25-0x28); the Linux table needs the evdev codes `KEY_KP1`-`KEY_KP9` and `KEY_UP`/`KEY_DOWN`/`KEY_LEFT`/`KEY_RIGHT`. Verify `KeyCodeCoverageTests` passes. Satisfies CON-002. | | |
| TASK-054 | Create `mobile/lib/data/services/camera_pad_mode.dart` following PAT-001: `enum CameraPadMode { numpad, arrow }` with wire values, a `prefsKey` of `wheeldeck.camera_pad_mode`, and a `fallback` of `numpad`. Satisfies REQ-017. | | |
| TASK-055 | Create `mobile/lib/ui/features/driving/views/camera_pad.dart`. Render a 3x3 `Grid`-equivalent `Stack` of nine cells. Each direction cell is a `DashboardControl` in `momentary` mode. In arrow mode, disable the four diagonal cells, which carry no wire identifiers. The center cell is a new `ControlMode.tapOrHold`. Satisfies REQ-017 and CON-006. | | |
| TASK-056 | In `dashboard_panel.dart`, add `tapOrHold` to the `ControlMode` enum and implement it in `_DashboardControlState`: on press, start a `Timer` of the widget's `holdDuration`; on release before it fires, send `ActionType.press`; on the timer firing, invoke a new `onHoldCompleted` callback, suppress the press, and fire `HapticFeedback.mediumImpact()`. Cancel the timer in `dispose`, satisfying PERF-002. Satisfies REQ-017. | | |
| TASK-057 | In `camera_pad.dart`, resolve the mode through the driving view model (REQ-017's authority lives there): in numpad mode call `input.activate` with the numpad-set `ControlId`; in arrow mode call it with the `camera_pad_arrow_*` `ControlId`. In arrow mode the four diagonals are disabled and emit nothing. Satisfies REQ-017 and CON-006. | | |
| TASK-058 | In `camera_pad.dart`, give the center cell a visual for both states: a progress indication during the three-second hold, and the active mode (`NUM` or `ARR`) otherwise, so the user can tell which keys the pad is sending. Satisfies REQ-017. | | |
| TASK-059 | Wire the pad into `block_grid.dart`'s `cameraPad` case, replacing the Phase 2 placeholder from TASK-017. Satisfies REQ-017. | | |
| TASK-060 | In `settings_view_model.dart` and `settings_screen.dart`, load and expose `CameraPadMode` and include it in `resetToDefaults`. No Settings UI is required — the pad is the switch surface — but the value must persist and reset. Satisfies REQ-017. | | |
| TASK-061 | Create `mobile/test/ui/features/driving/camera_pad_test.dart` asserting: in numpad mode a tap on the up cell emits `camera_pad_up`; in arrow mode the same cell emits `camera_pad_arrow_up`; in arrow mode the four diagonals are disabled and emit nothing; a tap on the center emits `camera_pad_recenter`; a three-second hold switches mode, emits no press action, and persists; a hold released early emits the press action and does not switch mode. Satisfies REQ-017 and PERF-002. | | |

### Implementation Phase 8

- GOAL-008: Make bindings gamepad-first with hybrid routing. The mapping mode
  becomes a route priority on the desktop and a display fallback on the phone.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-062 | In `desktop/WheelDeck.Core/Input/InputMapper.cs`, change `ApplyButton` so `Mode` selects the preferred route with cross-table fallback: in `ControllerButton` mode route through `DefaultButtonBindings` when the control's `ButtonId` is not `None`, otherwise through `DefaultKeyBindings`; in `SimulatedKeyPress` mode the priority is reversed. A control bound to `None` in both tables stays inert. Add a code comment recording the hybrid-routing decision. Satisfies REQ-022. | | |
| TASK-063 | In `mobile/lib/data/services/controller_preset.dart`, change `bindingFor` so gamepad mode consults `ets2Gamepad` first and falls back to `ets2Keyboard` for controls the gamepad map lacks. The send gate, Settings binder, and cell enabled-states follow automatically. Satisfies REQ-023. | | |
| TASK-064 | In `mobile/lib/data/services/input_mapping.dart`, flip `fromWireValue`'s fallback from `keyboard` to `gamepad`, and include the mapping in settings `resetToDefaults` so it restores `gamepad`. Satisfies REQ-024. | | |
| TASK-065 | Create `protocol/schema/mapping_message.json` describing the `{"type":"mapping","mode":"keyboard"|"gamepad"}` frame, mirroring `button_message.json`'s shape. Satisfies REQ-025. | | |

## 3. Alternatives

- **ALT-001**: Redesign the gyro layout with its own block grid. Rejected: no
  gyro defect is reported, and CON-004 keeps the working layout intact. Gyro
  changes are limited to signal placement.
- **ALT-002**: Keep `SignalArrows` as a separate widget and add separate signal
  cells to the grid. Rejected: duplicate rendering paths and duplicated blink
  logic for the same two controls.
- **ALT-003**: Represent the camera pad as a new analog axis in the protocol.
  Rejected for this version: a new axis is protocol work on both sides, and the
  in-game default bindings are discrete keys. Recorded as future work in
  `plan/feature-custom-button-layout-1.md`.
- **ALT-004**: Ship the whole enum expansion as one phase. Rejected: splitting
  by block keeps each phase independently verifiable, and isolates block C's
  non-mechanical work from the rest.
- **ALT-005**: Send the cleared turn signal's key so the desktop state machine
  matches the app. Rejected after in-game verification that ETS2 cancels the
  opposite signal itself, which makes the extra send unnecessary and contrary to
  REQ-009.

## 4. Dependencies

- **DEP-001**: `DESKTOP_KEYCODE_TABLES` — CON-002's two backend key tables must
  accept the new keys before any Phase 6 or 7 control can be sent. This blocks
  TASK-045 and TASK-053.
- **DEP-002**: `PROTOCOL_SCHEMA_PARITY` — CON-003's contract tests must stay
  green. Every enum addition in TASK-037, TASK-043, and TASK-051 requires its
  schema entry to land in the same change.
- **DEP-003**: `PRESET_OVERRIDE_ORDER` — REQ-020 depends on the existing
  resolution order in `DrivingViewModel._bindingFor`, which is already correct.
  No change needed; it must not be regressed.

## 5. Files

- **FILE-001**: `mobile/lib/ui/features/driving/views/driving_view.dart` —
  layout switch, AppBar removal, exit dialog, gyro signal row.
- **FILE-002**: `mobile/lib/ui/features/driving/views/dashboard_panel.dart` —
  rectangular shape, signal cells, icon resolver, `tapOrHold` mode.
- **FILE-003**: `mobile/lib/ui/features/driving/views/pedal_panel.dart` —
  label removal, hue colouring, slot-derived sizing.
- **FILE-004**: `mobile/lib/ui/features/driving/views/rotatable_wheel.dart` —
  spring-back animation and arc geometry.
- **FILE-005**: `mobile/lib/ui/features/driving/views/signal_arrows.dart` —
  deleted.
- **FILE-006**: `mobile/lib/data/services/dashboard_send_gate.dart` — signal
  mutual exclusion.
- **FILE-007**: `mobile/lib/data/services/driving_layout.dart` — new. Block and
  cell model plus the Sequential preset.
- **FILE-008**: `mobile/lib/data/services/spring_back.dart` — new. Spring-back
  preference, in its own file.
- **FILE-009**: `mobile/lib/data/services/camera_pad_mode.dart` — new. Camera
  pad input mode preference.
- **FILE-010**: `mobile/lib/ui/features/driving/views/block_grid.dart` — new.
  The layout renderer.
- **FILE-011**: `mobile/lib/ui/features/driving/views/camera_pad.dart` — new.
- **FILE-012**: `mobile/lib/ui/features/driving/view_models/driving_view_model.dart`
  — spring-back state, preset loading.
- **FILE-013**: `mobile/lib/ui/features/settings/views/settings_screen.dart` —
  mode gating, spring-back switch, new control labels.
- **FILE-014**: `mobile/lib/ui/features/settings/view_models/settings_view_model.dart`
  — spring-back and camera mode persistence, reset coverage.
- **FILE-015**: `mobile/lib/data/services/dashboard_input.dart` — ControlId
  additions.
- **FILE-016**: `mobile/lib/data/services/controller_preset.dart` — preset
  binding entries.
- **FILE-017**: `mobile/lib/data/services/dashboard_visibility.dart` — possible
  toggleable additions.
- **FILE-018**: `desktop/WheelDeck.Core/Protocol/ControlId.cs` — ControlId
  additions.
- **FILE-019**: `desktop/WheelDeck.Core/Output/KeyCode.cs` — KeyCode additions.
- **FILE-020**: `desktop/WheelDeck.Core/Input/InputMapper.cs` — key and button
  binding registrations, plus hybrid routing in `ApplyButton`.
- **FILE-021**: `desktop/WheelDeck.Backends/Windows/SendInputKeySimulator.cs` —
  Windows virtual-key rows.
- **FILE-022**: `desktop/WheelDeck.Backends/Linux/UinputBackend.cs` — evdev rows.
- **FILE-023**: `protocol/schema/controls.json` — schema entries.
- **FILE-024**: `protocol/schema/mapping_message.json` — new. Schema for the
  mapping frame.

## 6. Testing

- **TEST-001**: `dashboard_panel_test.dart` — a turn-signal cell renders a
  straight-arrow icon, and lights during the gate's blink phase.
- **TEST-002**: `dashboard_send_gate_test.dart` — turning right on while left is
  on clears left's visual and emits no left-side event; the reverse also holds.
- **TEST-003**: `dashboard_send_gate_test.dart` — reversed per REQ-021: signals
  send during hazard, keep blinking their own state, and hazard is unaffected.
  The old suppression regression test is replaced.
- **TEST-004**: `pedal_panel_test.dart` — no label text renders; track and fill
  use the correct hue per pedal.
- **TEST-005**: `driving_layout_test.dart` — the six block rects tile the 8x15
  grid without overlap; clutch occupies cols 4-5 rows 1-4 of block A;
  accelerator is right-most in block F; the wheel's layout box is square with
  diameter equal to block D's pixel height, horizontally centered with equal
  margins and flush bottom at a 2400x1080 constraint; every non-null slot
  control exists in `ControlId.values`.
- **TEST-006**: `rotatable_wheel_test.dart` — spring-back on animates to zero
  and reports zero; spring-back off holds the angle and reports it; an in-flight
  spring-back is cancelled by a new drag.
- **TEST-007**: `rotatable_wheel_test.dart` — zero steering paints no fill.
- **TEST-008**: `driving_view_model_test.dart` — spring-back loads from
  preferences and defaults to on; `resetToDefaults` restores on.
- **TEST-009**: New widget test — the back-press dialog renders three actions,
  `Stay` dismisses without side effects, and `Disconnect` leaves the coordinator
  disconnected without pushing the connection screen.
- **TEST-010**: New widget test — gyro layout renders two signal cells in both
  dashboard states; rotatable renders them as block A cells.
- **TEST-011**: `control_mode_test.dart` — `tapOrHold` sends a press on a short
  tap and calls the hold callback on a long press without sending a press.
- **TEST-012**: `camera_pad_test.dart` — mode-dependent control emission
  (`camera_pad_*` in numpad mode, `camera_pad_arrow_*` in arrow mode), diagonals
  disabled in arrow mode, center-cell tap and hold behaviour, and persistence
  across a reload.
- **TEST-013**: `mobile/test/data/services/control_contract_test.dart` — must
  pass unchanged after every Phase 5, 6, and 7 enum addition.
- **TEST-014**: `desktop/WheelDeck.Tests/ControlIdContractTests.cs` and
  `KeyCodeCoverageTests.cs` — must pass unchanged after every Phase 5, 6, and 7
  addition.
- **TEST-015**: New test group in `desktop/WheelDeck.Tests/` — in gamepad mode a
  dual-bound control fires its button and a key-only control fires its key; in
  keyboard mode the reverse; a control bound to `None` in both tables stays
  inert. Satisfies REQ-022.
- **TEST-016**: `controller_preset_test.dart` (created if absent) — gamepad mode
  resolves keyboard-only controls through the keyboard fallback map; a stored
  override still wins. Satisfies REQ-023.
- **TEST-017**: `input_mapping_test.dart` (created if absent) — the default
  mapping is `gamepad` and `resetToDefaults` restores it. Satisfies REQ-024.

## 7. Risks & Assumptions

- **RISK-001**: `KeyCodeCoverageTests` fails the build for every new `KeyCode`
  until both backend tables are updated. Mitigation: TASK-045 and TASK-053 pair
  each enum addition with both table rows in one change.
- **RISK-002**: `ControlIdContractTests` and `control_contract_test.dart` fail
  for any enum addition without a matching schema entry. Mitigation: DEP-002
  requires the schema edit in the same change as the enum edit.
- **RISK-003**: Phase 1 renders a partly empty screen because most of blocks A,
  B, C, and E are holes. Mitigation: accepted by design. Placement is the thing
  Phase 1 exists to let the user judge, and it is judgeable with the controls
  that exist.
- **RISK-004**: The `popScope` interception may swallow back events while the
  settings screen is pushed on top of the driving view. Mitigation: scope
  `PopScope` to the driving view only, not to the app, and cover it in TEST-009.
- **RISK-005**: Replacing the fixed 64-pixel control size with cell-derived
  sizing may break the compact-phone rectangle fallback at the 380-pixel
  breakpoint that the current code special-cases. Mitigation: cell sizing is
  already rectangular at every width, so the `compact` branch is removed rather
  than ported; verify on a narrow binding in TEST-001.
- **RISK-006**: The camera pad's two identifier sets could drift against the
  desktop bindings that resolve them. Mitigation: the identifiers are the
  single source of truth — `InputMapper` binds the numpad set to the Numpad
  keys and the arrow set to the arrow keys, with `ButtonId.None` for every pad
  control, so there is no second live mapping to drift.
- **ASSUMPTION-001**: A 1x1 cell's aspect follows the screen; no aspect
  correction is applied and none is needed — the grid tiles whatever the screen
  is. At 2400x1080 a cell is 160x135.
- **ASSUMPTION-002**: ETS2 cancels the opposite turn signal itself. Verified by
  the user in game. If this changes, REQ-009's no-send rule leaves app and truck
  desynced, and the fallback is to send the cleared signal's key.
- **ASSUMPTION-003**: The desktop resolves keys from control identifiers, so the
  mobile side needs no key names. Confirmed by reading `InputMapper.RouteKey`,
  which ignores any phone-supplied key string.
- **ASSUMPTION-004**: The 700ms spring-back and its `easeOutCubic` curve are
  starting values, not calibrated ones. Expect to tune them once the wheel is in
  hand, in the same way the release curve in `PedalInput` is tunable.
- **RISK-007**: Hybrid routing changes which path dual-bound controls take in
  gamepad mode (button instead of key). Intended; keyboard-mode behaviour is
  preserved because keys are checked first there, and no button-only controls
  exist today, so the keyboard-mode fallback path is currently unused.
- **ASSUMPTION-005**: ETS2's default gamepad bindings cover the driving core as
  researched, and the phone-side `ets2Gamepad` map mirrors them; extras without
  gamepad equivalents fall back to their keyboard keys.

## 8. Related Specifications / Further Reading

- `plan/plan-revamp-dashboard-v2.md` — the design notes this plan supersedes.
- `plan/feature-custom-button-layout-1.md` — deferred work: user-editable
  layout, custom profiles, additional presets, camera control types.
- `plan/feature-rotatable-steering-and-dashboard-1.md` — the prior feature that
  introduced rotatable steering.
- `protocol/schema/controls.json` — the shared control contract both sides code
  against.
- `plan/controls/` and `plan/references/` — ETS2 control screenshots and the
  Logitech, Thrustmaster, and Fanatec button-layout research.
- `docs/adr/0006-camera-pad-wire-identifiers.md` — why the camera pad's input
  mode lives in the wire identifiers.
