# Plan — feature/revamp-desktop-ui (desktop Avalonia revamp)

Branch: `feature/revamp-desktop-ui` · worktree: `../WheelDeck-feature-revamp-desktop-ui`
Base: `main` @ 7be9fdd · baseline: `dotnet test` 47/47 pass.

Stack: Avalonia 11.3.20 + FluentTheme, net10.0. No theme infra today
(`App.axaml` = bare `<FluentTheme />`). Window built in code
(`MainWindow.cs`: 520×420, no `WindowStartupLocation`, `TabControl` nav).

## Phase 0 — Quick fixes (connection tab, fonts, window position)

### TASK-001 — Status reflects session, not listener
Root cause: `ConnectionViewModel.UpdateFrom` (`ViewModels/ConnectionViewModel.cs:65`)
sets `StatusText = "Listening on port {port}"` whenever `isRunning`, never
consulting session state. A connected phone changes nothing on screen.
- Add `IsDeviceConnected` + `ConnectedDeviceName` to VM; `StatusText` derives:
  connected → `"Connected to {name}"`, else `"Listening on port {port}"` / `"Stopped"`.
- Feed session state: `CompositionRoot` already surfaces pairing events
  (`MainWindow.cs:31` `PairingCompleted` handler). Hook session connect/disconnect
  the same way (check `CompositionRoot`/`PairingService` for existing
  session events first — reuse, don't add new ones).
- `UpdateFrom` keeps signature; callers (`MainWindow.cs:25,35`) pass session state.
- Verify: unit test in `WheelDeck.Tests` (VM untested today): connected shows
  device name, disconnect falls back to Listening. `dotnet test` green.

### TASK-002 — "Active device" → "Paired device"
- `ConnectionView.axaml:18` label → `"Paired device:"`.
- Rename VM prop `ActiveDevice` → `PairedDevice` (+ binding, `MainWindow.cs:33`
  comment "refresh the active-device label"). Docstring update.
- Verify: build + test green. (Rename is whole-word; only 3 touch points.)

### TASK-003 — Fonts too small
- Centralize in `App.axaml`: `Styles` with `TextBlock` sizes
  (header 22→26, body default 14, hints 12) instead of per-view literals.
- Update `ConnectionView`/`PairingView`/`SetupView` headers to style.
- Verify: run app, eyeball all three tabs. No test (visual).

### TASK-004 — Center window at launch
- `MainWindow.cs`: `WindowStartupLocation = CenterScreen;`, bump default size
  (520×420 cramped after redesign — 880×600).
- Verify: launch, window centered. One line, no test.

## Phase 1 — Dark/light mode

- `App.axaml`: `<FluentTheme Mode="..."/>` bound to a setting; toggle button in
  new shell header (Phase 2) flips `Application.Current.RequestedThemeVariant`
  (`ThemeVariant.Dark`/`Light`, default: follow system = unset).
- Persist choice: plain text/JSON next to pairing store (check where
  `PairingManager` persists first — reuse that mechanism, no new infra).
- Verify: toggle survives restart; both variants render all tabs.

## Phase 2 — Shell redesign (replaces TabControl)

- `MainWindow.cs`: replace `TabControl` with sidebar nav
  (Connection | Pairing | Setup | Settings | About | Donate) + content area.
  Keep it code-built like today — matches existing style, no new pattern.
- Connection tab: status card (colored dot + `StatusText`), grid rows for
  Address / Paired device, firewall reminder as `InfoBar`-ish bordered card.
  8pt-ish spacing, rounded corners (`CornerRadius="8"`), consistent margins.
- Pairing/Setup tabs: same card treatment, no logic changes.
- Verify: `dotnet build`, manual click-through every nav item, light+dark.

## Phase 3 — Settings / About / Donate pages

- `SettingsView(+VM)`: theme toggle (mirrors header button), port display,
  firewall reminder moved here from Connection? (decision: keep reminder on
  Connection, Settings holds theme + port + "open data folder" if trivial).
  Keep minimal — only what exists elsewhere in the app today.
- `AboutView`: app version (assembly), repo link
  `github.com/fazrigading/WheelDeck`, credit line. Open URL via
  `Launcher.LaunchUriAsync` (Avalonia built-in — mobile Donate "Open" bug was
  a mobile-side issue, not a pattern to copy).
- `DonateView`: 3 link buttons mirroring mobile
  (`buymeacoffee.com/fazrigading`, `paypal.me/fazrigading`, `ko-fi.com/fazrigading`),
  same launcher.
- Verify: each link opens browser; `dotnet test` green.

## Out of scope / deferred

- New Settings knobs with no backing store (custom port, autostart) — add when
  `CompositionRoot` supports them.
- Mobile parity items (controller toggles, dashboard) — separate branches.

## Assumptions (flag if wrong)

1. Donation URLs = mobile's three. 2. Settings page minimal (theme/port/info),
   no new persistence beyond theme choice. 3. Sidebar nav acceptable vs tabs.
