# Cutover Leftovers

Started at the close of Task 12 (`efe0e58`) and kept live through the cutover
(`ed05111` → the Task 15 commit). Everything here is **not done**. The migration
is finished and `mobile/` is deleted, so this is the list of what a returning
driver has lost or never had, and what is still unverified.

Where this said "deferred", read "shipped in Flutter and never ported" — the
layout editor and its three presets were *finished work* on the Flutter side
(`plan/feature-custom-button-layout-1.md`, status Completed), not a backlog item.
The Dart source is on `backup/flutter-port`.

## The layout editor, three presets, and `LayoutProfileStore` did not come across

This is the largest gap and the only outright regression. Flutter shipped, in the
`#76` custom-layout work:

- `LayoutProfileStore` — named profiles with a persisted active name
- the layout *edit* API — `applyMove`, `addControl`, `removeSlot`, `freeSpans`
- the `Simple Automatic`, `Real Automatic`, and `H-Shifter` presets alongside
  `Sequential`

Kotlin has `DrivingLayout.sequential` and a read-only `BlockGrid`. So
`DrivingUiState.layout` never varies, the settings screen has no Layout preset
section, and **the camera section's "hide when the layout has no camera pad slot"
rule is unreachable** — it was reduced to rotatable-only because every layout
Kotlin knows about has a pad.

Two Dart test files have no Kotlin counterpart for the same reason:
`driving_layout_edit_test.dart` and `layout_profile_test.dart`. Neither is a port
gap to close; both describe code that does not exist yet.

**To port it:** the reference is `mobile/lib/data/services/layout_profile.dart`
and the edit half of `driving_layout.dart`, both on `backup/flutter-port`.

## The camera-pad `auto` alias does not make the pad work in gamepad mode

`TODO.md` Dashboard 4 asks that the camera pad's keybinds default to `auto` so
the driver is not prompted for a keybind on first press. Task 12 delivers the
prompt half: `GamePreset.bindingFor` falls back to `auto` for every
`camera_pad_*` control in **both** mapping modes, so a pad cell renders live and
its first press sends.

It does not deliver the working half. The desktop's own gamepad table
(`desktop/WheelDeck.Core/Input/InputMapper.cs:223-235`) binds all 13
`camera_pad_*` to `ButtonId.None`, and `InputMapping.fallback` is `Gamepad`. So
on a fresh install the pad cells are live and the desktop discards what they
send. The pad drives the game only in keyboard mapping mode.

This is a desktop gap, not a phone one — the phone has no keybind it could
print that the desktop would honour in gamepad mode. Two ways out, neither
picked:

- Give the desktop real gamepad bindings for the numpad block and arrows, so
  the pad works in the default mapping mode.
- Make gamepad mode bind the camera pad to the same virtual buttons the desktop
  already uses elsewhere, via the profile's `sendMappingMode`.

Out of scope for the phone migration. Flagging it so it is not discovered later
as a "the phone sends and nothing happens" bug.

## The gyro signal row does not exist yet

`mobile/lib/ui/features/driving/views/driving_view.dart:420` has a `_signalRow()`
that renders the two turn-signal cells above the left pedal column in **gyro**
mode. The rotatable grid's block A slots already carry them (Task 11), but the
gyro layout — pedal columns, per-pedal sides, the shared dashboard wrap, and
the signal row that sits above them — is one Flutter widget that has not been
ported at all.

So in gyro mode the Kotlin app has no signal cells. The gate is fully
implemented and tested (`SignalRowTest`); nothing renders it. This needs the
gyro-mode layout, which is not a Task 12 slice.

## `signal_row_test`'s placement assertions have no replacement

All four cases in the Dart suite are pixel assertions: the row sits above the
left pedal column with the dashboard hidden, stays put when the dashboard is
shown, sits in block A's top-left in rotatable mode, and blocks B/C/E render
regardless of `showDashboard`. The ported `SignalRowTest` covers the behaviour
those assertions guard — one cell per signal, toggle mode, bound in both mapping
modes, mutual exclusion, hazard independence, the light cycle, high-beam
independence — but not the geometry.

Consequence: nothing catches a regression that moves a signal cell. It needs a
device (or an emulator job this repo does not have), so it is Checkpoint B
work.

## Resolved: unbound controls are now bindable

Was true from Task 12 through Task 13. Tapping an unbound dashboard cell now
opens [BindingEditDialog](../android/app/src/main/kotlin/dev/fazrigading/wheeldeck/ui/features/settings/views/BindingEditDialog.kt)
and the Keybind Configuration page lists all 92 controls. Kept here because the
note that prompted the change is worth not losing.

## The PWA, and with it the iOS client, are gone

`release.yml` built a web bundle from the Flutter build and deployed it to GitHub
Pages. There is no web target any more, so iOS has no client at all. It was P2 and
never served natively, so nothing that demonstrably worked is lost — but the
supported-platforms table in `README.md` no longer lists iOS, and that is a real
reduction in stated reach, not a documentation tidy-up.

## The camera pad's simple and analog shapes have no renderer

`CameraControlType` (D-pad / Simple / Analog) persists and the settings screen
offers it, but only the D-pad renders. Tapping Simple or Analog changes a stored
value and nothing on screen. The D-pad's own shapes were also part of the
unported `#76` work.

## `clearBindingOverrides` was deleted

Code review flagged it as speculative: no production caller, and `SettingsRepository.resetAll`
is Task 13's. Rather than leave an unexercised method, it went. Task 13's reset
needs to re-add it and, this time, a caller.
