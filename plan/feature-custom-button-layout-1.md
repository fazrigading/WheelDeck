---
goal: Let the user move, resize, and add or remove dashboard controls, with profiles, modules, additional layout presets, and selectable camera control types
version: 1.2
date_created: 2026-09-17
last_updated: 2026-09-22
owner: Fazri Gading
status: 'Planned'
tags: [feature, mobile, layout, editor, backlog]
---

# Introduction

![Status: Planned](https://img.shields.io/badge/status-Planned-blue)

> **2026-09-22:** Phase 1 complete — TASK-001 through TASK-005 settled (see
> Phase 1 table and section 7). DEP-002 cleared: the fixed Sequential placement
> was judged good in the running app. Plan un-held (On Hold → Planned);
> Phases 2 through 7 unblocked.

This plan delivers a user-editable dashboard layout: the user moves controls
between cells, adds and removes them, and saves the result as a profile. It then
layers on modules (reusable multi-cell groups), additional layout presets, and
selectable camera control types.

Phase 1 exists to settle the design questions the editor raises; Phases 2 through
7 are the build.

REQ-001 makes this cheap to start: the v2 plan already declares the grid as data
rather than nested widget literals, so this plan extends an existing model
instead of replacing one.

## 1. Requirements & Constraints

### Functional requirements

- **REQ-001**: The grid added by `plan/feature-driving-dashboard-v2-1.md` stays
  declared as data in `mobile/lib/data/services/driving_layout.dart`. The editor
  must extend that model, not replace it. This plan does not introduce a second
  layout representation.
- **REQ-002**: The user can move any control to a different cell within the same
  block or across blocks.
- **REQ-003**: The user can add available controls to empty cells and remove
  controls, returning their cells to empty.
- **REQ-004**: The editor is constrained to whole cells. A control occupies
  whole cells only; free-form pixel placement is out of scope.
- **REQ-005**: A move that would overlap an occupied cell is refused. The editor
  must not push neighbouring controls, and must not allow overlap. See
  ASSUMPTION-003 for the rationale and the alternative.
- **REQ-006**: The user can create a named profile, switch between profiles, and
  switch between their own profiles and the developer-shipped presets.
- **REQ-007**: Developer-shipped presets are read-only. A user cannot overwrite
  one in place; saving while a preset is selected creates or updates a user
  profile instead.
- **REQ-008**: A profile records layout only. Bindings, pedal sides, and
  visibility stay in their existing stores and remain global. See ASSUMPTION-004.
- **REQ-009**: A module is a named rectangle plus an item list, reusing the same
  cell model as a slot. Modules ship as presets, not as a separate concept.
- **REQ-010**: The following modules ship: **Audio player**, 1 row x 5 columns;
  **H-Shifter**, 4x4.
- **REQ-011**: The following layout presets ship alongside the existing
  Sequential preset: **Simple Automatic**, **Real Automatic**, **H-Shifter**.
- **REQ-012**: The camera control type is selectable in Settings. Three types are
  defined in REQ-013, REQ-014, and REQ-016. (Semi-Analog deleted per TASK-005.)
- **REQ-013**: Camera type **Simple**: three buttons, each 3 rows x 1 column,
  inside a 3x3 module — Look Left Window (`Numpad/`), Recenter (`Numpad5`),
  Look Right Window (`Numpad*`).
- **REQ-014**: Camera type **D-pad**: eight directions plus a center recenter.
  The four diagonals (up-left, up-right, down-left, down-right) do not exist in
  this type. This is the type shipped by the v2 plan and remains the default.
- **REQ-015**: DELETED per TASK-005 (2026-09-22) — Semi-Analog had no design and
  the Analog type already covers continuous-axis users. Re-add only with a
  concrete specification.
- **REQ-016**: Camera type **Analog**: no recenter key. All nine directions are
  available, driven by a movable sphere inside a circular container, visually
  similar to an Xbox or PlayStation analog stick. This type requires a
  continuous axis, which the D-pad type does not.
- **REQ-017**: The editor is reachable from the driving screen without
  disconnecting, and exiting the editor restores driving input.
- **REQ-018**: When layout-preset switching ships (REQ-006), the desktop binding
  tables become preset-scoped so each preset carries its own default key and
  button assignments. Until then, `InputMapper`'s global tables plus the phone's
  `controller_preset.dart` remain the Sequential preset's binding source. New
  presets follow the hybrid routing rule of
  `plan/feature-driving-dashboard-v2-1.md` REQ-022.

### Constraints

- **CON-001**: No new dependency is added to `mobile/pubspec.yaml`. The editor
  uses `flutter/material.dart` for drag, snap, and hit-testing.
- **CON-002**: Every layout profile persists through `SharedPreferences`,
  following the existing preference pattern in
  `mobile/lib/data/services/wheel_mode.dart`.
- **CON-003**: The editor must not regress REQ-017 of
  `plan/feature-driving-dashboard-v2-1.md` — the camera pad's input mode stays
  phone-local and must never be sent to the desktop.
- **CON-004**: REQ-016's continuous axis is protocol work on both the mobile and
  desktop sides. It is out of scope for this plan's editor phases and is gated
  behind its own protocol addition.

### Guidelines and patterns

- **GUD-001**: Follow the view-model pattern in
  `mobile/lib/ui/features/driving/view_models/driving_view_model.dart`: a
  `ChangeNotifier` with immutable snapshot getters, rendered through
  `ListenableBuilder`.
- **GUD-002**: Follow the preference pattern in
  `mobile/lib/data/services/wheel_mode.dart`: a `prefsKey`, a `fallback`, and
  static `load` plus instance `save` methods.
- **PAT-001**: Model the profile store on
  `mobile/lib/data/services/dashboard_visibility.dart`, which already serialises
  a set of enum values to `SharedPreferences` and back with unknown values
  dropped on load.

### Performance requirements

- **PERF-001**: A drag in the editor must not rebuild the whole grid. Only the
  dragged control and its candidate target cell repaint.

## 2. Implementation Steps

### Implementation Phase 1

- GOAL-001: Settle the five design decisions this plan depends on, recording
  each outcome in this file. Phases 2 through 7 must not begin until every task
  in this phase is complete, because each one changes the shape of the work.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-001 | Confirm or override ASSUMPTION-001 (phone owns the layout; sync to the desktop is out of scope). Record the outcome by replacing ASSUMPTION-001's text in this file with a settled **REQ-018** bullet. If the outcome is desktop-authored, TASK-022 and TASK-023 change scope and the plan must be revised before Phase 4. **Outcome 2026-09-22: confirmed phone-owns; recorded in ASSUMPTION-001 as settled (no new REQ number — REQ-018 is already taken by the binding-table scope rule). No scope change to TASK-022/TASK-023.** | x | 2026-09-22 |
| TASK-002 | Confirm or override ASSUMPTION-002 (no transport between devices in this plan). If the outcome is that the desktop authors the layout, record the chosen transport — a JSON export and import file, a new WebSocket message type, or the phone pulling a desktop-authored file — as a new requirement, and add the corresponding `protocol/schema` entry to section 5. **Outcome 2026-09-22: confirmed no transport; no new requirement, no section 5 entry.** | x | 2026-09-22 |
| TASK-003 | Confirm or override ASSUMPTION-003 (overlapping drops are refused). If the outcome is push-neighbours or allow-overlap, replace REQ-005's text and add the resulting editor interaction rules to Phase 3 as new tasks. **Outcome 2026-09-22: confirmed refuse-overlap; REQ-005 unchanged, no new Phase 3 tasks.** | x | 2026-09-22 |
| TASK-004 | Confirm or override ASSUMPTION-005 (one layout per device, not per aspect class). If a layout is needed per aspect class, add the aspect-keying rule to REQ-006 and add a migration task to Phase 4 covering profiles saved before the rule existed. **Outcome 2026-09-22: confirmed one layout per device; REQ-006 unchanged, no Phase 4 migration task.** | x | 2026-09-22 |
| TASK-005 | Replace REQ-015 with a concrete Semi-Analog specification, or delete REQ-015 and the Semi-Analog tasks from Phase 7. Record which was done in this file. **Outcome 2026-09-22: deleted — REQ-015 removed, TASK-039 enum drops `semiAnalog`, TASK-045 removed, REQ-012 now reads three types. Re-add Semi-Analog only with a real design.** | x | 2026-09-22 |

### Implementation Phase 2

- GOAL-002: Extend the layout model from immutable preset data to a mutable,
  editable model, and add an edit mode to the driving view.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-006 | In `mobile/lib/data/services/driving_layout.dart`, add value equality and a `copyWith` to `CellRect`, and a `copyWith` to `LayoutSlot` so both can be rebuilt during an edit without mutation. Satisfies REQ-001 and REQ-002. | | |
| TASK-007 | In the same file, add `LayoutEditResult applyMove(DrivingLayout layout, CellRect from, CellRect to)` returning either the new layout or a refusal reason. Refuse when `to` overlaps an occupied slot, per REQ-005, and expose the reason so the editor can show why a drop failed. Satisfies REQ-005. | | |
| TASK-008 | In the same file, add `LayoutEditResult addControl(DrivingLayout layout, CellRect at, ControlId control)` and `LayoutEditResult removeSlot(DrivingLayout layout, CellRect at)`. Both refuse when the target span is already occupied. Satisfies REQ-003. | | |
| TASK-009 | In the same file, add `Set<CellRect> freeSpans(DrivingLayout layout, int rowSpan, int colSpan)` returning every position where a slot of the given span fits without overlap. The editor uses this to highlight valid drop targets, which is what enforces REQ-004's whole-cell constraint. Satisfies REQ-004. | | |
| TASK-010 | Create `mobile/lib/ui/features/driving/view_models/layout_edit_view_model.dart`. It wraps a `DrivingLayout`, exposes `beginEdit()`, `cancelEdit()`, `move(from, to)`, `addControl(at, control)`, `remove(at)`, and `saveAs(String name)`, and exposes `freeSpans` for the current drag. Every mutation is best-effort and never throws, per GUD-002. Satisfies REQ-002, REQ-003, and REQ-017. | | |
| TASK-011 | In `mobile/lib/ui/features/driving/views/block_grid.dart`, add an `editing` bool and an `onEditIntent` callback. When `editing` is true, route drag gestures on a slot to the edit view model instead of to the control's activation, so tapping a button in edit mode selects it rather than sending its event. Satisfies REQ-017. | | |
| TASK-012 | In `mobile/lib/ui/features/driving/views/driving_view.dart`, add an edit-mode entry point and an edit-mode exit that restores normal input. Satisfies REQ-017. | | |

### Implementation Phase 3

- GOAL-003: Build the editor surface: drag to move, tap to select, add and
  remove controls, with visible drop targets and refusals.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-013 | Create `mobile/lib/ui/features/driving/views/layout_editor.dart`. It renders the current layout through the existing `BlockGrid` with `editing: true`, and overlays a `Positioned` highlight for every rect in `freeSpans` for the current drag span. Satisfies REQ-002 and REQ-004. | | |
| TASK-014 | In the same file, make each occupied slot draggable. On drag start, capture the slot's span; on drag update, compute the target `CellRect` from the pointer position against the block geometry; on drag end, call `move(from, to)`. Highlight the candidate target only when it is in `freeSpans`. Satisfies REQ-002 and PERF-001. | | |
| TASK-015 | In the same file, render a refusal when `applyMove` rejects a drop: flash the target red and leave the layout unchanged. Do not push neighbours, per REQ-005. Satisfies REQ-005. | | |
| TASK-016 | In the same file, show a picker of controls available to add, sourced from every `ControlId` value that has a binding resolved in either input mapping mode. Placing one calls `addControl`. Satisfies REQ-003. | | |
| TASK-017 | In the same file, add a remove affordance on each selected slot calling `remove`. Removing a `SlotKind.pedal` or `SlotKind.wheel` slot is refused, because those slots are structural rather than additive. Satisfies REQ-003. | | |
| TASK-018 | In the same file, add a save action that prompts for a profile name and calls `saveAs`. A name matching a developer preset is refused, per REQ-007. Satisfies REQ-006 and REQ-007. | | |
| TASK-019 | Create `mobile/test/ui/features/driving/layout_editor_test.dart` asserting: a move into a free span succeeds; a move onto an occupied span is refused and the layout is unchanged; a move on a control outside edit mode still sends its activation event; a removal of a structural slot is refused; and a save using a developer preset's name is refused. Satisfies REQ-002, REQ-003, REQ-005, and REQ-007. | | |

### Implementation Phase 4

- GOAL-004: Persist layouts and profiles, and let the user switch between their
  own profiles and the developer presets.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-020 | Create `mobile/lib/data/services/layout_profile.dart`. Define `class LayoutProfile { final String name; final DrivingLayout layout; final bool isDeveloperPreset; }` and a `LayoutProfileStore` following PAT-001, serialising to `SharedPreferences` under the key `wheeldeck.layout_profiles`. Satisfies REQ-006 and CON-002. | | |
| TASK-021 | In the same file, serialise each profile as a JSON string via `dart:convert`, holding the profile name, an `isDeveloperPreset` flag always written false, and one entry per slot with its rect and control wire value. Satisfies REQ-006 and CON-002. | | |
| TASK-022 | In the same file, drop unknown control wire values on load and substitute `SlotKind.hole`, so a profile saved by an older build still loads after an enum change. Follow PAT-001's precedent in `DashboardVisibility.load`. Satisfies CON-002. | | |
| TASK-023 | In the same file, expose `List<LayoutProfile> loadAll()` merging the persisted user profiles with the developer presets compiled into the app. A persisted entry whose name matches a developer preset is ignored on load, enforcing REQ-007 at the storage boundary as well as in the editor. Satisfies REQ-006 and REQ-007. | | |
| TASK-024 | In `mobile/lib/ui/features/driving/view_models/driving_view_model.dart`, add the active profile name, load it in `init`, expose it, and resolve the active `DrivingLayout` from it. Add `selectProfile(String name)` and include the active profile in `resetToDefaults`. Satisfies REQ-006. | | |
| TASK-025 | In `mobile/lib/ui/features/settings/views/settings_screen.dart`, add a `Layout profile` section listing every profile from `LayoutProfileStore.loadAll()`, marking developer presets as read-only. Selecting one calls `selectProfile`. Satisfies REQ-006 and REQ-007. | | |
| TASK-026 | Create `mobile/test/data/services/layout_profile_test.dart` asserting: a saved profile round-trips to an identical layout; an unknown control wire value loads as a hole; a persisted entry naming a developer preset is ignored; and a rename preserves the layout. Satisfies REQ-006, REQ-007, and CON-002. | | |

### Implementation Phase 5

- GOAL-005: Add modules — reusable named rectangles — and ship the Audio player
  and H-Shifter modules.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-027 | In `mobile/lib/data/services/driving_layout.dart`, add `class LayoutModule { final String name; final int rowSpan, colSpan; final List<LayoutSlot> slots; }`. A module is placed as one unit and its slots are offset by the placement rect. Satisfies REQ-009. | | |
| TASK-028 | In the same file, define the **Audio player** module at 1 row x 5 columns holding `audioVolumeDown`, `audioPrevious`, `audioPlayPause`, `audioNext`, `audioVolumeUp`. All five identifiers already exist in `ControlId`. Satisfies REQ-010. | | |
| TASK-029 | In the same file, define the **H-Shifter** module at 4x4. Its slot contents depend on TASK-005's gate logic, which is not yet specified; emit every cell as a hole and record the gap in section 8 rather than inventing placements. Satisfies REQ-010. | | |
| TASK-030 | In `mobile/lib/ui/features/driving/views/layout_editor.dart`, add module placement to the add flow: a module is placed as one unit against a 4x4 or 1x5 free span, refused when no such span exists. Satisfies REQ-009. | | |
| TASK-031 | Add to `mobile/test/ui/features/driving/layout_editor_test.dart`: placing the Audio player module at a free 1x5 span succeeds and yields five controls at the expected relative positions; placing it where no 1x5 span exists is refused. Satisfies REQ-009 and REQ-010. | | |

### Implementation Phase 6

- GOAL-006: Ship the Simple Automatic, Real Automatic, and H-Shifter layout
  presets.

| Task | Description | Completed | Date |
|------|-------------|-----------|----------|
| TASK-032 | Confirm that every control the three presets call for exists in `ControlId` on both sides. The Sequential preset's Phase 5, 6, and 7 additions in `plan/feature-driving-dashboard-v2-1.md` are expected to cover this; record any control still missing and add it following that plan's CON-003 contract, which requires a schema entry in the same change as the enum entry. Satisfies REQ-011. | | |
| TASK-033 | Add `static DrivingLayout simpleAutomatic()` to `driving_layout.dart`. Satisfies REQ-011. | | |
| TASK-034 | Add `static DrivingLayout realAutomatic()` to `driving_layout.dart`. Satisfies REQ-011. | | |
| TASK-035 | Add `static DrivingLayout hShifter()` to `driving_layout.dart`, placing the H-Shifter module from TASK-029. Satisfies REQ-010 and REQ-011. | | |
| TASK-036 | Register the three presets in `LayoutProfileStore.loadAll()` as developer presets, per TASK-023. Satisfies REQ-007 and REQ-011. | | |
| TASK-037 | Add matching keyboard entries to
  `mobile/lib/data/services/controller_preset.dart` for any control the three
  presets introduce that is not already present. Satisfies REQ-011. | | |
| TASK-038 | Extend `mobile/test/data/services/driving_layout_test.dart` from
  `plan/feature-driving-dashboard-v2-1.md` with the same structural assertions
  for each new preset: slots tile their blocks without overlap, and every
  non-null slot control exists in `ControlId.values`. Satisfies REQ-011. | | |
| TASK-047 | Scope the desktop binding tables per active preset once REQ-011's presets exist: extend `InputMapper` with per-preset key and button tables (or a preset overlay applied at preset-selection time), so each preset carries its own defaults per REQ-018. Satisfies REQ-018. | | |

### Implementation Phase 7

- GOAL-007: Make the camera control type selectable, and implement the Simple
  and Analog types.

| Task | Description | Completed | Date |
|------|-------------|-----------|----------|
| TASK-039 | Create `mobile/lib/data/services/camera_control_type.dart` following PAT-001: `enum CameraControlType { dpad, simple, analog }` with wire values, a `prefsKey` of `wheeldeck.camera_control_type`, and a `fallback` of `dpad`. (`semiAnalog` removed per TASK-005.) Satisfies REQ-012 and CON-002. | | |
| TASK-040 | In `mobile/lib/ui/features/settings/views/settings_screen.dart`, add a `Camera control` section with a `SegmentedButton` over `CameraControlType`, visible only when the layout contains a camera pad slot. Satisfies REQ-012. | | |
| TASK-041 | In `mobile/lib/ui/features/driving/views/camera_pad.dart`, dispatch on the selected type, keeping the existing D-pad implementation as the `dpad` branch. Satisfies REQ-012 and REQ-014. | | |
| TASK-042 | In the same file, implement the `simple` branch: three buttons each 3 rows x 1 column inside the 3x3 region — Look Left Window on `Numpad/`, Recenter on `Numpad5`, Look Right Window on `Numpad*`. Add `KeyCode.NumpadDivide` and `KeyCode.NumpadMultiply` to `desktop/WheelDeck.Core/Output/KeyCode.cs` and to **both** backend key tables, per CON-002 of `plan/feature-driving-dashboard-v2-1.md`. Satisfies REQ-013. | | |
| TASK-043 | Implement the `analog` branch's protocol addition before its UI: add an interior-camera axis to the state message and to `InputMapper.ApplyState` in `desktop/WheelDeck.Core/Input/InputMapper.cs`, following the existing steering axis path. This is CON-004's gated protocol work. Satisfies REQ-016 and CON-004. | | |
| TASK-044 | Implement the `analog` branch's UI in `camera_pad.dart`: a movable sphere inside a circular container reporting continuous x and y, visually modelled on a controller analog stick, with no recenter key. Satisfies REQ-016. | | |
| TASK-045 | DELETED per TASK-005 (2026-09-22) — REQ-015 removed, no `semiAnalog` branch. | — | 2026-09-22 |
| TASK-046 | Create `mobile/test/ui/features/driving/camera_control_type_test.dart` asserting: each type renders its documented shape; the type persists across a reload; `resetToDefaults` restores `dpad`; and the Simple type emits `NumpadDivide`, `Numpad5`, and `NumpadMultiply`. Satisfies REQ-012, REQ-013, and REQ-014. | | |

## 3. Alternatives

- **ALT-001**: Keep the layout hardcoded in widget literals and generate an
  editor later by parsing the widget tree. Rejected: the v2 plan declares the
  grid as data at near-zero cost, which removes the need for this entirely.
- **ALT-002**: Free-form pixel placement with snapping. Rejected: the grid is
  already cell-based, and whole-cell placement keeps collision rules arithmetic
  rather than geometric.
- **ALT-003**: Push neighbouring controls out of the way on an overlapping drop.
  Rejected as the default: it makes a drag's outcome depend on layout history,
  which is hard to predict and harder to undo. Recorded as the alternative in
  ASSUMPTION-003.
- **ALT-004**: Build the editor in another language to gain a richer UI toolkit.
  Rejected: Flutter covers drag, drop, snap, and hit-testing without a new
  dependency, so the editor stays in the existing app.
- **ALT-005**: A separate editor application that writes layout files the phone
  loads. Rejected for this version: it adds a distributed half of the app for a
  feature used on the phone itself. It remains the fallback shape if
  TASK-001 selects a desktop-authored layout.
- **ALT-006**: Make profiles capture bindings, pedal sides, and visibility as
  well as layout. Rejected: those settings already have their own stores and
  per-preset behaviour, and folding them in would create two sources of truth.
  Recorded in ASSUMPTION-004.

## 4. Dependencies

- **DEP-001**: `DRIVING_LAYOUT_MODEL` — `mobile/lib/data/services/driving_layout.dart`
  and the `BlockGrid` renderer must exist first. Both are delivered by Phases 2
  and 2 of `plan/feature-driving-dashboard-v2-1.md`. This blocks all of Phase 2.
- **DEP-002**: `SEQUENTIAL_PLACEMENT_ACCEPTED` — the fixed Sequential placement
  must be judged good in the running app before the editor's UX is worth
  building. This is why the plan is On Hold. This blocks TASK-001.
- **DEP-003**: `CONTROL_ENUM_COMPLETENESS` — REQ-011's presets and REQ-010's
  modules need their controls to exist on both sides. `plan/feature-driving-dashboard-v2-1.md`
  Phases 5 through 7 add them. This blocks TASK-032.
- **DEP-004**: `CAMERA_AXIS_PROTOCOL` — REQ-016's continuous axis is new protocol
  work on both sides. This blocks TASK-043 and TASK-044.
- **DEP-005**: `PRESET_SCOPED_DESKTOP_TABLES` — REQ-018's per-preset desktop
  tables require the hybrid-routing and preset machinery from the v2.1 plan to
  be landed and judged. This blocks TASK-047.

## 5. Files

- **FILE-001**: `mobile/lib/data/services/driving_layout.dart` — extended with
  mutation helpers, `LayoutModule`, and the new presets.
- **FILE-002**: `mobile/lib/ui/features/driving/views/block_grid.dart` — gains
  `editing` and `onEditIntent`.
- **FILE-003**: `mobile/lib/ui/features/driving/views/driving_view.dart` — gains
  the edit-mode entry point.
- **FILE-004**: `mobile/lib/ui/features/driving/views/layout_editor.dart` — new.
- **FILE-005**: `mobile/lib/ui/features/driving/view_models/layout_edit_view_model.dart`
  — new.
- **FILE-006**: `mobile/lib/data/services/layout_profile.dart` — new.
- **FILE-007**: `mobile/lib/data/services/camera_control_type.dart` — new.
- **FILE-008**: `mobile/lib/ui/features/driving/views/camera_pad.dart` —
  extended with type dispatch, the Simple shape, and the Analog shape.
- **FILE-009**: `mobile/lib/ui/features/driving/view_models/driving_view_model.dart`
  — active profile resolution.
- **FILE-010**: `mobile/lib/ui/features/settings/views/settings_screen.dart` —
  profile section and camera control section.
- **FILE-011**: `mobile/lib/ui/features/settings/view_models/settings_view_model.dart`
  — camera control type persistence and reset coverage.
- **FILE-012**: `mobile/lib/data/services/controller_preset.dart` — preset
  binding entries for the new presets.
- **FILE-013**: `desktop/WheelDeck.Core/Output/KeyCode.cs` — `NumpadDivide` and
  `NumpadMultiply`.
- **FILE-014**: `desktop/WheelDeck.Backends/Windows/SendInputKeySimulator.cs` —
  a virtual-key row per new `KeyCode`.
- **FILE-015**: `desktop/WheelDeck.Backends/Linux/UinputBackend.cs` — an evdev
  row per new `KeyCode`.
- **FILE-016**: `mobile/lib/data/services/dashboard_input.dart` — only if
  TASK-032 finds a control still missing.
- **FILE-017**: `desktop/WheelDeck.Core/Protocol/ControlId.cs` — only if
  TASK-032 finds a control still missing.
- **FILE-018**: `protocol/schema/controls.json` — only if TASK-032 finds a
  control still missing, or if TASK-002 selects a desktop transport.

## 6. Testing

- **TEST-001**: `layout_editor_test.dart` — a move into a free span succeeds.
- **TEST-002**: `layout_editor_test.dart` — a move onto an occupied span is
  refused, the layout is unchanged, and no neighbour moves.
- **TEST-003**: `layout_editor_test.dart` — a control outside edit mode still
  sends its activation event, so editing does not disturb driving.
- **TEST-004**: `layout_editor_test.dart` — removing a structural slot such as
  the wheel or a pedal is refused.
- **TEST-005**: `layout_editor_test.dart` — saving under a developer preset's
  name is refused.
- **TEST-006**: `layout_profile_test.dart` — a profile round-trips through
  `SharedPreferences` to an identical layout.
- **TEST-007**: `layout_profile_test.dart` — a profile containing an unknown
  control wire value loads with that slot as a hole.
- **TEST-008**: `layout_profile_test.dart` — a persisted entry naming a
  developer preset is ignored, keeping presets read-only at the storage
  boundary.
- **TEST-009**: `layout_editor_test.dart` — the Audio player module places at a
  free 1x5 span with the expected relative positions, and is refused where no
  such span exists.
- **TEST-010**: `driving_layout_test.dart` — each new preset's slots tile their
  blocks without overlap and every non-null slot control exists in
  `ControlId.values`.
- **TEST-011**: `camera_control_type_test.dart` — each camera type renders its
  documented shape and the Simple type emits `NumpadDivide`, `Numpad5`, and
  `NumpadMultiply`.
- **TEST-012**: `camera_control_type_test.dart` — the camera type persists across
  a reload and `resetToDefaults` restores `dpad`.
- **TEST-013**: `mobile/test/data/services/control_contract_test.dart` — must
  pass unchanged after any control addition in TASK-032.
- **TEST-014**: `desktop/WheelDeck.Tests/KeyCodeCoverageTests.cs` — must pass
  unchanged after the `KeyCode` additions in TASK-042.
- **TEST-015**: `desktop/WheelDeck.Tests/ControlIdContractTests.cs` — must pass
  unchanged after any control addition in TASK-032.

## 7. Risks & Assumptions

- **RISK-001**: The editor's UX cannot be validated until Sequential placement is
  accepted, so building it early risks rework. Mitigation: DEP-002 gates the
  whole plan; only Phase 1 may proceed before that gate.
- **RISK-002**: REQ-016's continuous axis duplicates transport work if a second
  axis is later added for another control. Mitigation: TASK-043 follows the
  existing steering axis path rather than inventing a second mechanism, so a
  later axis reuses it.
- **RISK-003**: Stored profiles can outlive the `ControlId` enum they were saved
  against, silently changing a user's layout. Mitigation: TASK-022 converts
  unknown wire values to holes rather than dropping the slot, and TEST-007
  covers it.
- **RISK-004**: `LayoutProfileStore.loadAll()` merging persisted profiles with
  compiled-in presets on every read may be slow if a user accumulates many
  profiles. Mitigation: profiles are small and the list is read on screen entry,
  not per frame. If it becomes measurable, cache the merged list and invalidate
  on write.
- **RISK-005**: Closed 2026-09-22 — REQ-015 deleted and TASK-045 removed per
  TASK-005, so no unspecified enum value remains.
- **ASSUMPTION-001**: SETTLED 2026-09-22 (TASK-001) — confirmed: the phone owns
  the layout; desktop-authored arrangement stays out of scope.
- **ASSUMPTION-002**: SETTLED 2026-09-22 (TASK-002) — confirmed: no transport
  between phone and desktop for layout data in this plan.
- **ASSUMPTION-003**: SETTLED 2026-09-22 (TASK-003) — confirmed: an overlapping
  drop is refused rather than pushing neighbours or allowing overlap.
  Predictable and trivially undoable, since the layout is unchanged.
- **ASSUMPTION-004**: A profile captures layout only; bindings, pedal sides, and
  visibility remain global. Not gated by a Phase 1 task: no requirement in this
  plan depends on it except REQ-008, which states it directly. Revisit if a user
  expects a profile to carry their bindings too.
- **ASSUMPTION-005**: SETTLED 2026-09-22 (TASK-004) — confirmed: one layout
  applies per device, not per aspect class. The cell model is proportional, so a
  layout authored at one aspect reflows acceptably at another.
- **ASSUMPTION-006**: The H-Shifter module's slot contents are not yet specified.
  TASK-029 emits holes and records the gap rather than guessing.

## 8. Related Specifications / Further Reading

- `plan/feature-driving-dashboard-v2-1.md` — the prerequisite plan. Supplies the
  layout model, the `BlockGrid` renderer, the camera pad's D-pad type, and the
  control and key enum expansion this plan builds on.
- `plan/plan-revamp-dashboard-v2.md` — the design notes behind the prerequisite
  plan.
- `plan/plan-revamp-dashboard-v2.md`'s Sequential preset section — the placement
  whose acceptance gates this plan.
- `plan/references/steering-wheel-button-research.md` — button-layout research
  that informs the H-Shifter module's contents, which ASSUMPTION-006 leaves open.
- `docs/adr/0006-camera-pad-wire-identifiers.md` — camera control types
  (REQ-013, REQ-016) add their own wire identifier sets under the same
  pattern.
