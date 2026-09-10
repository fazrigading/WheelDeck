# TODO — Mobile & Desktop UI Revamp

> Detailed plan: `plan/fix-mobile-revamp-followup-1.md` (followup fixes) · prior `plan/feature-revamp-mobile-ui-1.md` (ALL PHASES DONE)

## branch: feature/revamp-desktop-ui
- [ ] connection tab showing active when it's not connected
- [ ] pairing tab
- [ ] default window position at launch should be in the middle not top left
- [ ] add dark/light mode button
- [ ] redesign whole UI
- [ ] create settings page

---

### new problems (found in 2026-09-10):
- [x] After status connected, pressing the "Ready to Drive" should open the Driving page, not when pressing the "Back" button on top-left.
- [x] Disconnecting from the Driving page should go back to "Connect" page, not to the "Menu"
- [ ] "Open" button on Donate page is not working.
- [ ] Changing Controller Type and Pedal Layout doesn't do anything, no changes on the Driving page.
- [ ] Editing "Button bindings" on Settings Page does not change the shown keys/buttons.
- [ ] "Reset to Default" on Setting page is shown half / 50% vertically in Portrait mode.
- [ ] (Special request) Create a guide page for the Steam setup in settings page, which it needs the user to press each button on the virtual joystick, so just add pressable buttons exactly how XBOX 360 controllers .

### new feature for branch `feature/revamp-dashboard` (after problem above solved):
- [ ] Light modes actually has 2 modes (Parking Lights & Low Beam), so toggling it would change the the text and the button visually
- [ ] Fix existing buttons:
  - [ ] Change "Cruise Control" keybind to `C`
  - [ ] Change "HI" button name to "High-beam" `K`
  - [ ] Resize the dashboard button size.
- [ ] New Buttons:
  - [ ] Add "Hazard Lights" button (`F`)
  - [ ] Add "Warning / Beacon Lights" button (`O`)
  - [ ] Add "Light Horn / Flasher" button (`J`)
  - [ ] Add "Horn" button in the center of the Steering Wheel (`H`)
  - [ ] Add "Lift / Drop Axle" button (`U`)
- [ ] Blinking button for Left-Right Turn Signal
- [ ] Add additional settings section:
  - [ ] Create option for "Engine Start" button on dashboard can be hold or just press, also make it visually toggled ON in both option.
  - [ ] Create toggles for these buttons:
    - [ ] Auxiliary lights (`F4`)
    - [ ] Air Horn (`N`)
    - [ ] Differential Lock
    - [ ] Start/Stop Engine Electricity (keybind set by user)
    - [ ] Wipers Back (keybind set by user)


## branch: `feature/revamp-mobile-ui` — M3 revamp (5 phases) 

Status: ALL PHASES DONE

> Detailed plan: `plan/feature-revamp-mobile-ui-1.md`

### Phase 0 — Foundation (M3 + Menu shell) ✅
- [x] **Menu page** — logo, title, Connect/Settings/About/Donate buttons. M3 (`ThemeData(useMaterial3:true, ColorScheme.fromSeed)`), 8pt grid, thumb-zone CTAs. → `mobile/lib/ui/features/menu/views/menu_screen.dart`, `mobile/lib/ui/core/theme/app_theme.dart`, `mobile/lib/main.dart` routing
- [x] Extract M3 tokens (colorScheme, textTheme max 4 sizes/2 weights, 60/30/10) to `app_theme.dart`
- [x] Stub About/Donate so Menu navigates

### Phase 1 — Connect page ✅
- [x] **Status card** — M3 `Card` with icon+label+progress for `ConnectionStatus` (tinted via `colorScheme`). Replaces `ConnectionStatusBanner` (`connection_screen.dart:269`)
- [x] **Paired list** — previously paired devices section (persist `host:port` via `PairedDeviceRepository`)
- [x] **Unpaired separated** — new/discovered devices in distinct section below paired
- [x] **Manual add FAB → modal** — replace inline `_ManualEntry` row (`connection_screen.dart:114`) with `FAB(Icons.add)` → `showModalBottomSheet(ManualAddSheet)`
- [x] **IP/Port filtering** — `FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))` for IP, `digitsOnly` for Port + validation
- [x] **PIN not censored** — `obscureText: false` on `_PairingPrompt` (`connection_screen.dart:237`)

### Phase 2 — Driving page ✅
- [x] **Manual recalibration/zeroing button** — FAB or AppBar `Icons.center_focus_strong` → `DrivingViewModel.recalibrate()` → `sensorRepository.setCenter()` even when not `awaitingCalibration`
- [x] **Fix notification-pane disconnect bug** — `LifecycleObserver.dart:16`: `inactive` (notification shade) must NOT call `pause()`; only `paused`/`detached`. On `resumed` auto-reconnect via `lastTarget` if needed. See plan TASK-014/015 for debounce alternative.

### Phase 3 — Settings page ✅
- [x] **Per-control bindings** — editable list for both `keyboard` and `gamepad` mappings (`SettingsScreen.dart:56`, `input_mapping.dart:4`)
  - [x] ETS2 preset + extensible `GamePreset` (mirrors `desktop/WheelDeck.Core/Input/InputMapper.cs:13`)
- [x] **Controller type selector** — steering only / +3 pedals / +2 pedals / +dashboard / full
- [x] **Controller layout** — a) Acc R/Brake R/Clutch L  b) Acc R/Brake L/Clutch L  c) A w/o clutch  d) B w/o clutch → drives `PedalPanel` order/visibility
- [x] **Reset to default** — confirm dialog + `SnackBar`, resets mapping+type+layout

### Phase 4 — About & Donation ✅
- [x] **About** — developer credit, source code link, GitHub Stars button + badge (`shields.io` or `api.github.com/repos/fazrigading/WheelDeck`) → `ui/features/about/views/about_screen.dart`
- [x] **Donation** — 3 M3 cards linking via `url_launcher`: `https://buymeacoffee.com/fazrigading`, `https://paypal.me/fazrigading`, `https://ko-fi.com/fazrigading` → `ui/features/donate/views/donate_screen.dart`

### Phase 5 — Polish & QA ✅
- [x] M3 audit: 8pt grid, `rounded-2xl` cards, `44x44` targets, contrast, empty/loading/error/success states
- [x] Peak-End: connected sparkle/bounce, recalibration haptic
- [x] Tests + manual QA (notification shade, gyro drift, paired persist)

---

  