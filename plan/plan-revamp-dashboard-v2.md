# Plan: revamp driving dashboard v2

Status: **design settled** — 2026-09-17. No implementation started.

Two features live here. The **driving page revamp** fixes fourteen reported
defects and rebuilds the rotatable layout as a cell grid. The **Sequential
preset** is the first layout preset that grid renders. Deferred work is
recorded in `plan/feature-custom-button-layout-1.md`.

## Scope split

Rotatable mode only, except where noted as shared:

- **Shared** (both modes, changes one widget each): items 1, 2, 6, 8, 9, 14.
- **Rotatable only**: items 3, 4, 5, 7, 10, 11, 12, 13, and the grid layout.
- **Gyro only**: the `Pedal sides` and `Dashboard controls` Settings sections,
  plus a signal-placement correction.

`_gyroLayout` keeps its current structure. It gains no block grid and no new
placement logic.

## Layout geometry

The rotatable screen divides into 2 rows x 3 columns of blocks. Each block is
4 rows x 5 columns of cells. Every block has **20 cells**; block position is
written `[row, col]`, cell position `[row, col]` within its block.

Global grid is therefore 8 rows x 15 columns. One cell is `W/15 x H/8`, which
is exactly 4:3 on any landscape phone, so a 1x1 cell already satisfies the
rectangular-button requirement. No fixed 64px sizes survive: every button is
sized by its cell span via `LayoutBuilder`.

At 2400x1080: cell = 160x135, block = 800x540.

| Block | Pos | Region (cols x rows) | Contents |
|---|---|---|---|
| A | [1,1] | 1-5 x 1-4 | 12 buttons + clutch pedal |
| B | [1,2] | 6-10 x 1-4 | 20 buttons |
| C | [1,3] | 11-15 x 1-4 | gear up 2x2, gear down 2x2, camera pad 3x3, e-brake, engine brake, cruise |
| D | [2,1] | 1-5 x 5-8 | steering wheel 4x4 + a 4-cell button column |
| E | [2,2] | 6-10 x 5-8 | 20 buttons |
| F | [2,3] | 11-15 x 5-8 | 4 buttons + brake pedal + accelerator pedal |

Block-level detail:

- **A** — buttons `G H I L M N Q R S V W X`. Clutch pedal occupies
  `J-K, O-P, T-U, Y-Z` (cols 4-5, rows 1-4). With the clutch switched off those
  eight cells are deliberately left empty; the preset is one of several and a
  hole is expected.
- **C** — gear up `G-H, L-M`, gear down `Q-R, V-W` (both 2x2, stacked, up above
  down). Camera pad `I-J-K, N-O-P, S-T-U` (cols 3-5, rows 1-3) with recenter at
  the center. Row 4 holds emergency brake, engine brake, cruise control.
- **D** — wheel occupies cols 1-4, rows 5-8. Column 5 holds horn, flasher,
  wiper, light modes. Wheel diameter equals block height, so it sits flush to
  the screen's bottom-left corner with clear space to its right. The whole
  wheel is visible; the `clamp(160, 480)` in the current code is removed
  because it is what lets the wheel exceed the available height.
- **F** — col 1 holds engine electricity, engine start, parking brake, shift to
  neutral. Brake pedal `H-I, M-N, R-S, W-X` (cols 2-3). Accelerator pedal
  `J-K, O-P, T-U, Y-Z` (cols 4-5). Accelerator is right-most, correcting the
  current ordering.

Both pedals are 2 cells wide with a small inset inside each bar, which reduces
the current gap between them. Pedal height is rows 5-8, exactly half the screen
height, satisfied by geometry rather than a fixed size.

Block E sits between the wheel and the pedals, which is what the request to fill
the gap between them asked for; no additional widget is needed.

The grid is declared as **data**, not hardcoded widget nesting: one file holding
the block and cell specifications. This costs almost nothing now and means the
later layout editor is a UI problem over an existing model rather than a
rewrite.

## Row-by-row resolution of the fourteen items

1. **Remove the top bar.** The `AppBar` goes entirely. It currently holds the
   title, the recalibrate action, Settings, and Disconnect. Recalibrate survives
   as the existing floating action button. Settings and Disconnect move into the
   new back-navigation dialog (item 14).
2. **Rectangular buttons.** Cell-derived sizing makes every dashboard button
   4:3. Gear buttons are 2x2. The "3:4" in the original note is treated as stale
   because it contradicts the 2x2 cell span.
3. **Wheel size and anchor.** The reported 64px overflow is caused by the
   current layout, not by a rounding error: when the clutch is hidden the left
   `Column` has no `Expanded` child to absorb slack, so a fixed 64px signal row
   plus the wheel exceeds the body. The new layout derives wheel size from its
   block, which removes the cause. Wheel is flush bottom-left, fully visible.
4. **Pedal height and anchor.** Height is half the screen by geometry; pedals
   anchor bottom-right; padding tightens.
5. **Gap filled with dashboard items.** Satisfied by block E.
6. **Straight arrows for turn signals.** `Icons.arrow_back` and
   `Icons.arrow_forward` replace the curved icons. This is a glyph swap only.
7. **Slower spring-back, plus a toggle.** Release animates to zero over ~700ms
   with an eased curve instead of the current instant reset. A new setting turns
   the spring-back off; when off, the wheel holds the angle it was released at
   and steering stays there until the user drags it back. Default is **on**, so
   an upgrade does not silently change feel, and the reset-to-defaults action
   restores it.
8. **Pedal colours.** Labels `ACC`, `BRK`, `CLT` are removed. Track colour is
   the pedal's hue at 25% alpha over the existing dark base; the pressure fill
   is the same hue at full opacity. Accelerator blue, brake red, clutch yellow.
9. **Mutually exclusive signals.** Turning one signal on while the other is on
   clears the other's blinking **without sending the cleared signal's key**.
   Confirmed in game that ETS2 cancels the opposite signal itself, so app and
   truck stay in sync and no extra gate state is needed.
10. **Pedal sides setting is gyro-only.** It is meaningless in rotatable mode,
    where the layout fixes clutch top-left and brake/accelerator bottom-right.
11. **Clutch toggle in rotatable mode.** The clutch switch stays reachable in
    rotatable mode; accelerator and brake are already unconditional in the
    current code, so only the clutch needed a home. The `Dashboard controls`
    section is gyro-only (see item 10's reasoning and the preset decision below).
12. **Pedal order corrected.** Accelerator is right-most in rotatable mode.
13. **Wheel arc red bar.** Span stays 180 degrees across the top. The fill
    starts at twelve o'clock and grows toward the turned side, length
    proportional to the absolute steering value. Zero steering fills nothing.
14. **Back navigation confirmation.** Back press opens a dialog with three
    options: **Settings** (push the settings screen, refresh on return),
    **Disconnect** (disconnect and land on app Home), and **Stay** (dismiss).
    Disconnect no longer pushes the connection screen, which is a deliberate
    change from current behaviour.

## Sequential preset

The preset supplies cell contents and default bindings. User binding overrides
still win over preset defaults, so switching presets never discards per-control
customisation made in Settings.

Turn signals are no longer a bespoke widget. They become ordinary grid entries
rendered by `DashboardControl`, so the blink visual lives in the existing active
state rather than being duplicated. In gyro mode the same two controls render as
a row above the left pedal, preserving the current gyro appearance; they are no
longer a separate `SignalArrows` widget.

## Camera pad

A 3x3 module in block C. Eight directions plus a center cell.

The pad has two input modes. Numpad mode sends the ETS2 default camera keys
(`Numpad7/8/9`, `Numpad4/6`, `Numpad1/2/3`). Arrow mode sends the four arrow
keys for menu navigation; the four diagonal directions are **disabled** in this
mode because cards and menus have no diagonal.

The mode switch lives on the center cell and is **phone-local** — it is never
sent to the desktop. A tap on the center cell sends the recenter key
(`Numpad5`); a three-second hold switches input mode and suppresses the tap.
Arrow mode has no recenter key, so in that mode the center cell only switches
back. The cell shows a progress indication during the hold and the active mode
otherwise. The mode choice persists across restarts and is restored by
reset-to-defaults.

This needs a new interaction mode alongside the existing toggle, momentary, and
hold-confirm modes, because the current hold-confirm mode cannot express
"tap sends one action, hold sends a different one".

## Settings visibility by wheel mode

Gate row by row rather than hiding whole sections:

- **Rotatable** — `Clutch pedal` switch only, plus the new spring-back toggle
  and the camera pad options. `showDashboard` is ignored; blocks B, C, and E
  always render.
- **Gyro** — `Pedal sides`, `Dashboard controls`, and `Dashboard` visibility.

## Phasing

**Phase 1 — layout and the fourteen fixes.** Uses only controls that exist
end-to-end on both sides today: mobile `ControlId`, desktop `ControlId`,
desktop `KeyCode`, `InputMapper` defaults, and `protocol/schema/controls.json`.
Cells whose control does not exist yet render as holes. The screen is expected
to look partly unfinished; what Phase 1 exists to let you judge is placement,
and placement is judgeable with the controls that are there.

**Phase 2a — block A, D, F.** One new control identifier (trailer axle). Note
that `trailer` already exists but is not the same thing, and that truck axle
maps to the existing lift/drop axle control.

**Phase 2b — block B, E.** About twenty new control identifiers: driver and
passenger window up and down, navigation zoom in, overlay, chat, quick replies,
name tags, push to talk, five individual cameras, dashboard info, next camera,
menu, world map, photo mode, and activate.

**Phase 2c — block C.** The camera pad directions and recenter, the phone-local
mode flag, and the new tap-or-hold interaction mode. This is the only sub-phase
with non-mechanical work.

Phases 2a and 2b are plumbing, and each new control identifier costs an entry in
all of: mobile `ControlId`, mobile `_controlLabel`, the preset map, desktop
`ControlId`, `InputMapper.DefaultKeyBindings`, `InputMapper.DefaultButtonBindings`,
and `protocol/schema/controls.json`.

Each new key additionally costs a `KeyCode` member **plus a row in both backend
key tables** — `SendInputKeySimulator.VirtualKeyCodes` (Windows) and
`UinputBackend.KeyCodes` (Linux evdev). `desktop/WheelDeck.Tests/KeyCodeCoverageTests.cs`
enforces this: a missing row makes `SendKey` silently drop the key and fails the
build. Roughly twenty-one new keys are needed (`Tab`, `Comma`, `Dot`, `Slash`,
`RightShift`, `RightCtrl`, numpad 1-9, and the four arrow keys).

The desktop resolves keys from control identifiers, so mobile needs no key
names.

## Open items carried forward

- The camera pad's analog-stick idea (a ninth direction driven by a movable
  sphere) is **not** in this plan. Eight digital directions plus recenter are.
- Layout presets beyond Sequential — Simple Automatic, Real Automatic, and
  H-Shifter — are future work, as is a user-editable layout and profiles. See
  `plan/feature-custom-button-layout-1.md`.
- Gyro mode keeps its current design. If a specific gyro problem exists, it
  needs its own item; nothing in this plan addresses one.
