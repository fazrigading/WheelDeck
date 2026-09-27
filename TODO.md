# TODO

Remember to update the future plan status to `draft` or `ongoing` or `finished`

## New Issues

### Mobile

> **All seven resolved** in the Kotlin app, as the `migrate/flutter-to-kotlin`
> migration was required to build them right rather than port the bugs. Items
> marked *(device-pending)* are implemented and unit-tested but have never been
> exercised on hardware — Checkpoints B and C are still open. Verification steps:
> [`tasks/manual-checklist.md`](tasks/manual-checklist.md). Plan:
> [`plan/finished/migration-kotlin-1.md`](plan/finished/migration-kotlin-1.md).

Dashboard:

- [x] Resize gear button size to be 2 rows x 1 cols instead of 2 rows x 2 cols
- [x] Resize ACC + BRK pedals size to be 4 rows x 1.5 cols instead of 4 rows x 2 cols; we can create it as a one group so it will be 4 rows and 3 cols
- [x] Create a padding between blocks, except alongside to the screen.
- [x] Camera Pad keybinds for Up/Down/Left/Right must be set by default alias auto, not manual. Currently it's asking for keybinds after pressing the button in Driving page.
      *(Resolved for the prompt only — all 13 pad controls resolve to `auto` in both mapping modes, so the first press sends. In gamepad mode the desktop binds them to `ButtonId.None`, so the pad still does nothing there. That is a desktop gap.)*
- [x] When modal of above problem (edit keybinds) pops up, keyboard must afloat, must not resize the whole dashboard. *(device-pending)*

Controls:
- [x] "Rotate back to zero" feature in steering wheel is good at lower degrees value, but in higher value, it's still too fast. Create a constant turning back speed, slow and steady.
      *(Tested at 180 and 2520; the on-screen rate still needs eyes on a device.)*

Settings:
- [x] Create new page for Keybind Configuration inside Setting page

### Android (regressions from the cutover)

Features that shipped in the Flutter app and were **not** ported. The Dart source
is on `backup/flutter-port`; detail in
[`tasks/task-12-leftovers.md`](tasks/task-12-leftovers.md).

- [ ] Port the layout editor: `LayoutProfileStore`, the layout edit API
      (`applyMove`, `addControl`, `removeSlot`), and the `Simple Automatic` /
      `Real Automatic` / `H-Shifter` presets
- [ ] Render the camera pad's Simple and Analog shapes — `CameraControlType`
      persists and the settings screen offers it, but only the D-pad draws
- [ ] Port the gyro-mode layout, including the turn-signal row above the left
      pedal column. The rotatable grid has the signals; gyro mode has none
- [ ] Add placement assertions for the signal cells — the Dart suite's four
      pixel tests have no unit-test replacement
- [ ] Decide on an iOS client. The release workflow built a PWA from the Flutter
      build; there is no web target now, so iOS has no client
- [ ] Landscape lock on the driving screen. Flutter set and cleared it around the
      driving view; Kotlin does neither

### Desktop 

Note: this is done on `Linux Fedora 43 7.2.5-100.fc43.x86_64`
1. Steam detected "WheelDeck Virtual Controller" when it's not "Enabled via Steam Input". After enabling the Steam input, it's detected as Xbox 360 Controller.
2. Game detected that hardware name too if not enabled via steam input. But, the game cannot set it neither as steering wheel nor gamepad.
3. Maybe use a fake Hardware ID, like "MOZA TSW Truck Wheel" or "Logitech G923" or something similar (this should correspond to the degrees chosen because each actual wheel sim has different config) to trick the game and Steam and allowing the wheel control.
4. Wheel monitor is working, but the needle is not moving like it supposed to.

---


