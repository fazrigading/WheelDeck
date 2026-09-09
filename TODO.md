# TODO — Mobile UI Revamp

> Detailed plan: `plan/feature-revamp-mobile-ui-1.md`

## branch: `feature/revamp-mobile-ui` — M3 revamp (5 phases)

### Phase 0 — Foundation (M3 + Menu shell) ✅
- [x] **Menu page** — logo, title, Connect/Settings/About/Donate buttons. M3 (`ThemeData(useMaterial3:true, ColorScheme.fromSeed)`), 8pt grid, thumb-zone CTAs. → `mobile/lib/ui/features/menu/views/menu_screen.dart`, `mobile/lib/ui/core/theme/app_theme.dart`, `mobile/lib/main.dart` routing
- [x] Extract M3 tokens (colorScheme, textTheme max 4 sizes/2 weights, 60/30/10) to `app_theme.dart`
- [x] Stub About/Donate so Menu navigates

### Phase 1 — Connect page ✅
- [x] **Status card** — M3 `Card` with icon+label+progress for `ConnectionStatus` (tinted via `colorScheme`). Replaces `ConnectionStatusBanner` (`connection_screen.dart:269`) → `ConnectionStatusCard`
- [x] **Paired list** — previously paired devices section (persist `host:port` via `PairedDeviceRepository`)
- [x] **Unpaired separated** — new/discovered devices in distinct section below paired
- [x] **Manual add FAB → modal** — replace inline `_ManualEntry` row (`connection_screen.dart:114`) with `FAB(Icons.add)` → `showModalBottomSheet(ManualAddSheet)`
- [x] **IP/Port filtering** — `FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))` for IP, `digitsOnly` for Port + validation
- [x] **PIN not censored** — `obscureText: false` on `_PairingPrompt` (`connection_screen.dart:237`)

### Phase 2 — Driving page ✅
- [x] **Manual recalibration/zeroing button** — FAB + AppBar `Icons.center_focus_strong` → `DrivingViewModel.recalibrate()` → `sensorRepository.setCenter()` even when not `awaitingCalibration`
- [x] **Fix notification-pane disconnect bug** — `LifecycleObserver.dart:16`: `inactive` (notification shade) now no-op; only `paused`/`detached` triggers `pause()`. `resumed` retains `lastTarget` auto-reconnect via `CalibrationOverlay`.

### Phase 3 — Settings page ✅
- [x] **Per-control bindings** — editable list for both `keyboard` and `gamepad` mappings (`SettingsScreen.dart:56`, `input_mapping.dart:4`) — preset list with chip + tap-to-edit dialog
  - [x] ETS2 preset + extensible `GamePreset` (mirrors `desktop/WheelDeck.Core/Input/InputMapper.cs:13`)
- [x] **Controller type selector** — steering only / +3 pedals / +2 pedals / +dashboard / full (`ControllerType` + `RadioGroup`)
- [x] **Controller layout** — a) Acc R/Brake R/Clutch L  b) Acc R/Brake L/Clutch L  c) A w/o clutch  d) B w/o clutch → drives `PedalPanel` order/visibility (`PedalLayout` + `DrivingViewModel.pedalLayout`)
- [x] **Reset to default** — confirm dialog + `SnackBar`, resets mapping+type+layout

### Phase 4 — About & Donation
- [ ] **About** — developer credit, source code link, GitHub Stars button + badge (`shields.io` or `api.github.com/repos/fazrigading/WheelDeck`) → `ui/features/about/views/about_screen.dart`
- [ ] **Donation** — 3 M3 cards linking via `url_launcher`: `https://buymeacoffee.com/fazrigading`, `https://paypal.me/fazrigading`, `https://ko-fi.com/fazrigading` → `ui/features/donate/views/donate_screen.dart`

### Phase 5 — Polish & QA
- [ ] M3 audit: 8pt grid, `rounded-2xl` cards, `44x44` targets, contrast, empty/loading/error/success states
- [ ] Peak-End: connected sparkle/bounce, recalibration haptic
- [ ] Tests + manual QA (notification shade, gyro drift, paired persist)

---


branch: feature/revamp-desktop-ui
- [ ] ask agent what can be improved/revamped

  