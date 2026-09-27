# Task 12 Leftovers

Written at the close of Task 12 (`efe0e58`) so Task 13 inherits the context
instead of rediscovering it. Everything here is *deferred, not done* — the two
TODO.md fixes Task 12 claims to have made are only half-landed, and one
acceptance criterion has no replacement test.

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

## Unbound controls are inert and there is no way to bind them yet

Task 12 shipped the binding *resolution* (preset's table, stored overrides,
`resolveBinding`) but not the binding *editor*. `onBindRequested` has no port, so
a cell with no default renders disabled with a "—" badge and taps do nothing.

The controls this actually affects are the user-set-able ones with no default in
either table: `shift_to_drive`, `shift_to_reverse`, `shift_to_neutral`,
`engine_electricity`, `adaptive_cruise`, `cruise_speed_increase`,
`cruise_speed_decrease`, `lane_assistant`, `lane_keeping`, `emergency_brake`,
`wipers_back`, `audio_favorite`. The Sequential preset places several of them
(`adaptive_cruise`, `lane_keeping`, `lane_assistant` are block A cells), so
those cells are visibly dead. The Flutter app is in the same state by default
and its binder is a tap on the disabled cell.

Task 13's settings page and `onBindRequested` close this. It is the one
leftover that leaves the app worse to use than it could be, so it is the reason
Task 13 is next.

## `clearBindingOverrides` was deleted

Code review flagged it as speculative: no production caller, and `SettingsRepository.resetAll`
is Task 13's. Rather than leave an unexercised method, it went. Task 13's reset
needs to re-add it and, this time, a caller.
