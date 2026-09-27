# Manual Checklist

Everything here needs a physical Android device and a running desktop. **None of
it has been run yet** — Tasks 1-13 have unit coverage only, and Checkpoint B has
never been done.

Work through the sections in order: a failure early on makes the later ones
meaningless.

- [ ] **Setup** — desktop up, phone on the same Wi-Fi, `debug` APK installed
  - [ ] `./gradlew installDebug` succeeds
  - [ ] Desktop is running: `dotnet run --project WheelDeck.App`
  - [ ] Phone and desktop on the same network; phone in **landscape**

---

## 1. First launch and onboarding

The routing shell (`AppShell`) landed in Task 13; before that the app only ever
showed the connection screen.

- [ ] Fresh install (`adb uninstall dev.fazrigading.wheeldeck` first) launches
      into onboarding, not the connection screen
- [ ] Both permission tiles show; **no system permission dialog appears** — this
      is correct, neither permission is a runtime permission on Android
- [ ] "Continue" reaches the connection screen
- [ ] Kill and relaunch → onboarding does **not** reappear
- [ ] Uninstall, reinstall, tap "Skip for now" → connection screen, and relaunch
      does not show onboarding again

## 2. Connection

Tasks 3-6. Most of this was signed off in Checkpoint A, but the app now routes
through a new shell, so the transitions are worth re-walking.

- [ ] A running desktop appears in the discovered list without a manual refresh
- [ ] Tapping it shows the PIN prompt; the correct PIN reaches **Connected**
- [ ] Kill the app, relaunch → goes **straight to Connected**, no re-pair
- [ ] Wi-Fi off, wait 10s, Wi-Fi on → reconnects on its own, no tapping
- [ ] Background the app mid-session (home button) → returning shows the
      calibration gate asking to re-confirm the steering centre (ADR-0002)
- [ ] Revoke the phone on the desktop → the app drops the token and shows the
      connection screen rather than a dead Connected state

## 3. Driving surface

Tasks 7-10. This is the make-or-break section and has **never been run against a
game**.

- [ ] In rotatable mode, the dashboard grid renders: wheel, pedals, camera pad,
      and the control blocks per the Sequential preset
- [ ] Cells print short labels — `LIGHT`, `BEAM`, `HAZARD`, `GEAR+` — not
      `hazard_lights` or `gear_up`
- [ ] Drag the wheel → the truck steers, and the rotation indicator arc follows
- [ ] Release the wheel → it animates back to zero at the **same rate** whether
      the selected degree is 180 or 2520 (`TODO.md` Controls — this is the fix,
      verify it at both extremes)
- [ ] Drag each pedal → pressure maps 0.0-1.0; release → springs back to rest
- [ ] Camera pad: tap a direction → the in-game camera looks that way
- [ ] Long-press the pad centre for 3s → the pad switches between numpad and
      arrow glyphs, and the directions still work after the switch
- [ ] Switch to gyro mode in Settings → the dashboard is replaced by the tilt
      readout, and tilting the phone steers
      - **Expected gap:** in gyro mode there are **no turn-signal cells**. The
        gyro layout — pedal columns, per-pedal sides, and the signal row — is one
        Flutter widget that has not been ported. See
        [`task-12-leftovers.md`](task-12-leftovers.md). Not a regression; a
        known omission.

## 4. Dashboard controls

Task 12. These are gate-driven visuals; the gate is unit-tested, the rendering
is not.

- [ ] Left signal cell blinks at ~1.5 Hz
- [ ] Right signal cell blinks at ~1.5 Hz
- [ ] Turning one on **cancels** the other
- [ ] Hazard blinks **both** sides at once, independently of the signals
- [ ] Headlight cell cycles `OFF → PARK → LOW → OFF`, label following the stage
- [ ] High beam is independent of the light cycle
- [ ] `START` cell long-presses to confirm; the release sends nothing extra
- [ ] Every control the desktop receives shows up in the game's control
      configuration

## 5. Settings

Task 13. The section-visibility rules are unit-tested; the rendering is not.

- [ ] Gear icon in the top-right of the dashboard opens settings; so does the
      gear on the connection screen
- [ ] **Rotatable mode** shows: Input mode, Game preset, Wheel mode, Show
      controls, Camera control, Engine start, Keybind configuration, Reset
- [ ] **Rotatable mode** hides: Pedal sides, Dashboard controls
- [ ] **Gyro mode** shows Pedal sides and Dashboard controls, and hides Camera
      control
- [ ] `Clutch pedal` and `Dashboard` switches persist across a relaunch
- [ ] Changing rotation degrees persists and applies on the next launch
- [ ] Changing engine start mode to Single press → the `START` cell now fires on
      tap instead of long-press
- [ ] "Reset to default" restores gamepad, ETS2, 900°, hidden clutch, shown
      dashboard, default pedal sides, and rotate-back-to-zero

## 6. Keybind Configuration — `TODO.md` Settings

- [ ] Keybind configuration row opens a **second page**, not a list inside the
      settings scroll
- [ ] All 92 controls listed, each showing its effective binding
- [ ] The page title follows the mapping mode ("Gamepad buttons" / "Key
      bindings")
- [ ] Set a value, go back, and the row shows the new value
- [ ] Clear a value → the row shows `—`, and the control stops sending
- [ ] **The leftover this closes:** tap a dead cell on the dashboard (one of the
      unbound ones — `Lane assistant`, `Adaptive cruise`, `Emergency brake`, …).
      It opens the binder instead of doing nothing. Set a binding, and the cell
      comes alive.

## 7. `TODO.md` Dashboard 5 — keyboard floats, dashboard does not resize

**Implemented but unverified. Check this one carefully.**

- [ ] From the **dashboard**, tap an unbound cell to open the binder, and let
      the keyboard appear:
  - [ ] The **dashboard behind does not shift or resize**
  - [ ] The dialog sits **above** the keyboard, text field visible
- [ ] Dismiss the keyboard → the dashboard is back to its exact previous layout
- [ ] In the settings page itself, tap a text field → the settings list scrolls
      above the keyboard and the Save/Cancel buttons stay reachable
- [ ] Rotate the device while the binder is open → the dialog survives

> **Why this needs a device.** The fix is `decorFitsSystemWindows = false` plus
> `Modifier.imePadding`. An earlier version also forced
> `SOFT_INPUT_ADJUST_NOTHING` on the dialog window; review showed that can
> suppress `WindowInsets.ime` on **API 30+**, which would defeat the
> `imePadding` doing the work — so it was deleted. If the dialog hides behind
> the keyboard, note the Android version: that is the API-30+ inset path.

## 8. Camera pad mapping mode — expected limitation

- [ ] Default (gamepad) mode: pad cells look live, but the game does not respond
- [ ] Settings → Input mode → **Keyboard**, then pad cells drive the camera
- [ ] No keybind prompt on first press, in either mode (`TODO.md` Dashboard 4)

> This is a **desktop gap, not a phone one**: the desktop's gamepad table binds
> all 13 `camera_pad_*` controls to `ButtonId.None`, and gamepad is the default
> mapping. The `auto` alias fixes the prompt, not the routing. Details in
> [`task-12-leftovers.md`](task-12-leftovers.md).

## 9. Regression guard

- [ ] `flutter test` still passes in `mobile/` — no Dart file should have changed
- [ ] `./gradlew test` — 275 unit tests
- [ ] `./gradlew assembleDebug`
- [ ] The Flutter app still builds and pairs, as the reference implementation

---

## Known gaps that no amount of manual testing will close

These are omissions, not bugs to hunt for. They are listed here so a failed
expectation is not filed as a new issue.

- Gyro-mode signal row and the whole gyro layout (pedal columns, per-pedal sides)
- `signal_row_test`'s four placement assertions — pixel assertions with no
  unit-test replacement, so nothing catches a regression that moves a signal cell
- Layout profiles and the layout editor; `Sequential` is the only layout. This
  also defers the settings camera section's "hide when the layout has no camera
  pad slot" half, so that rule is currently rotatable-only
- Camera pad simple and analog shapes — `CameraControlType` persists but has no
  renderer
- No landscape lock on the driving screen. Flutter sets and clears it around the
  driving view; the Kotlin app does neither
- Menu, about, and donate screens (Task 14)

Detail on all of these: [`task-12-leftovers.md`](task-12-leftovers.md),
[`plan.md`](plan.md).
