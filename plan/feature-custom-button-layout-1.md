# Feature: user-customisable button layout

Status: **backlog** — not scheduled. Notes captured 2026-09-17 so the placement
work in `plan-revamp-dashboard-v2.md` can be built without painting into a
corner.

## Goal

Let the user move, resize, and add/remove dashboard buttons on the driving
screen, instead of living with the fixed preset grid.

## Why it is deferred

The v2 revamp settles *placement* only: which control goes in which cell of a
fixed 2x3 block / 4x5 cell grid, declared as a preset. Shipping an editor at
the same time means building a runtime layout model, an edit mode, collision
and snapping rules, persistence, and a save/load surface — a much larger
project whose UX cannot be judged until the fixed placement is known to be
good.

## What the revamp must do now (cheap, prevents a rewrite)

Declare the grid as data, not hardcoded widget nesting: one file holding the
block/cell specs. Cost is near zero. It reduces the future editor to a UI
problem over an existing model.

## Camera control types

A Settings switch selecting how the interior-camera block behaves. The v2
revamp ships the D-pad type only; the rest are future work.

- **Simple** — 3 buttons, each 3 rows x 1 col, inside the 3x3 module:
  Look Left Window (`Numpad/`), Recenter (`Numpad5`), Look Right Window
  (`Numpad*`).
- **D-pad** — the 4 diagonal directions (UL, UR, DL, DR) do not exist;
  recenter sits in the middle. 8 directions + center. Shipped in v2.
- **Semi-Analog** — undecided, needs its own design pass.
- **Analog** — no recenter; all 9 directions, driven by a movable sphere
  inside a circular container (visual similar to an Xbox/PS controller
  analog stick).

## Open questions for that discussion

1. Sync direction: does the desktop arrange the layout and push it to the
   phone, the phone push to the desktop, or is it device-local?
2. If desktop-authored: transport is unresolved — JSON export/import file vs a
   new WebSocket message type vs the phone pulling a desktop-authored file.
3. Collision and resize rules: what happens when a moved control overlaps an
   occupied cell. Push neighbours, refuse the drop, or allow overlap.
4. Cell granularity: is the editor constrained to whole cells, or free-form
   pixel placement with snapping.
5. Who owns grid geometry per device: one layout for all screen sizes, or a
   layout per aspect class.

## Custom profiles / presets

A user creates their own named profile and switches between it and the
developer-shipped presets without losing their own arrangement. Needs a
profile store, a switcher, and a rule for what a profile captures (layout only,
or also bindings, pedal sides, and visibility). The developer presets must be
read-only so a user cannot overwrite one by accident.

## Modules

A *module* is a named rectangle plus an item list — it falls out of the layout
model for free once placement is data. Ship as presets, not as a separate
concept.

Planned modules:

- Audio player, 1 row x 5 columns
- H-Shifter, 4x4

## Planned layout presets

Only **Sequential** exists in the v2 revamp. Remaining presets are future work:

- Sequential — shift up / shift down (the v2 preset, uses `gear_up` / `gear_down`)
- Simple Automatic
- Real Automatic
- H-Shifter

Each preset needs a matching set of `ControlId` values. Several controls the
Sequential preset calls for do not exist in the enum yet; see the scope
question raised during the v2 grilling.
