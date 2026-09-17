---
goal: Fix post-revamp mobile issues found 2026-09-10 (routing, donate, settings wiring, UI)
version: 1.0
date_created: 2026-09-10
last_updated: 2026-09-10
owner: fazrigading
status: Finished
tags:
  - fix
  - mobile
  - m3
  - followup
---

# Introduction

![Status: Finished](https://img.shields.io/badge/status-Finished-green)

Branch `fix/mobile-revamp-followup` off `main` (post-PR #27 c256364). 7 follow-up problems logged in `TODO.md:15` after the 5-phase M3 revamp (Menu, Connect, Driving, Settings, About, Donate). This plan fixes them without destabilizing the revamp.

Scope is strictly the 7 items; `feature/revamp-dashboard` stays separate until this lands.

## 1. Requirements & Constraints

- **REQ-001 Ready-to-drive CTA**: When `ConnectionStatus == connected`, tapping the status card's "Ready to drive" action must open `DrivingView`. Must not require pressing system Back. Currently `main.dart:75` auto-routes via `_Routing` when `status==connected`, but `ConnectionScreen` is shown inside `MenuScreen → Navigator.push` path, so the status change is not observed by the outer `_Routing` when inside a pushed route. Fix must make the CTA explicit + also ensure `_Routing` covers the pushed case or pop correctly.
- **REQ-002 Disconnect → Connect**: `_onDisconnect` in `driving_view.dart:112` currently calls `viewModel.disconnect()` → `coordinator.status==disconnected` → `_Routing` returns `MenuScreen()`. Requirement is to land on `ConnectionScreen`, not `Menu`. Need explicit navigation: either pop to `ConnectionScreen` or make `_Routing` route to `ConnectionScreen` when coming from Driving (or keep `MenuScreen` but push `ConnectionScreen` on disconnect).
- **REQ-003 Donate Open not working**: `donate_screen.dart:31` `_open` uses `canLaunchUrl` + `launchUrl(externalApplication)`. Common failures: missing `android:queries` for https, missing `LSApplicationQueriesSchemes` on iOS, or `canLaunchUrl` false because no browser. Fix: remove `canLaunchUrl` gate or handle false, ensure `url_launcher` manifest entries present, add error SnackBar, test on Android.
- **REQ-004 Controller Type / Pedal Layout wiring**: `SettingsViewModel` persists `ControllerType`/`PedalLayout` via `SettingsRepository`, `DrivingViewModel` loads `pedalLayout` in `init` but never refreshes after Settings and `ControllerType` is never consumed. Must make Driving react: reload layout on Settings pop, and apply `ControllerType` to hide/show `PedalPanel`/`DashboardPanel` or wheel per spec.
- **REQ-005 Button bindings edit**: Currently `_editBinding` in `settings_screen.dart:217` shows SnackBar with "(preset; custom save in future)" and never persists. Requirement: edits must change the shown chip. Minimal is to persist per-control override via `SharedPreferences` (e.g. `wheeldeck.binding.<control>.<mapping>`) and have `GamePreset` resolution prefer override; full map persistence deferred.
- **REQ-006 Reset layout clipping**: `settings_screen.dart:178` Reset button with `minimumSize height 48` inside `ListView` padding 16/24 is clipped to half vertically in portrait. Likely `SafeArea`/bottom inset or `ListView` + `Scaffold` FAB overlap, or parent `SizedBox width infinity` + `ListView` bottom padding insufficient. Fix: wrap in `SafeArea` bottom, add `padding: EdgeInsets.fromLTRB(..., 24 + MediaQuery.padding.bottom)` or use `bottomNavigationBar` / give `ListView` bottom `SizedBox 24`.

- **CON-001**: Keep `_Routing` as source of truth for `connected || isPaused` → `DrivingView`. Do not introduce `go_router` for this fix scope.
- **CON-002**: Minimum new deps. Prefer `SharedPreferences` for binding overrides, `url_launcher` already present.
- **GUD-001**: Follow existing structure — `ui/features/<feature>/views/` + `view_models/` + `data/services|repositories/`.
- **PAT-001**: Settings persistence via `SettingsRepository` already handles `InputMapping`; extend same pattern for bindings.

## 2. Implementation Steps

### Phase 1 — Navigation fixes (REQ-001, REQ-002)

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-001 | Add explicit CTA to `ConnectionScreen` when `status==connected`: show `FilledButton("Ready to Drive")` below `ConnectionStatusCard` (or make card tappable). On tap, `Navigator.of(context).maybePop()` if pushed from Menu then rely on `_Routing` to show Driving, or `Navigator.pushReplacement(DrivingView)` for immediate. Also ensure `_Routing` still auto-shows Driving when status becomes connected outside the pushed route (no regression). File: `mobile/lib/ui/features/connection/views/connection_screen.dart`. | ✅ | 2026-09-11 |
| TASK-002 | Fix disconnect destination: change `DrivingView._onDisconnect` + `DrivingViewModel.disconnect` to navigate to `ConnectionScreen` instead of `MenuScreen`. Option: after `await _viewModel.disconnect()`, if mounted, `Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const ConnectionScreen()), (r) => r.isFirst)` or pop to Menu then push Connect. Keep `_Routing` fallback to `MenuScreen` but override in Driving context. File: `mobile/lib/ui/features/driving/views/driving_view.dart`. | ✅ | 2026-09-11 |
| TASK-003 | Verify `main.dart:75` `_Routing` + `MenuScreen` push semantics: if user is on `Menu → Connection` and status becomes connected, ensure Driving appears without requiring Back. Could also make Menu's Connect button use `push` and on connected use `pop` + let `_Routing` handle Driving. Test both paths. | ✅ | 2026-09-11 |

### Phase 2 — External links (REQ-003)

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-004 | Harden `DonateScreen._open`: try `launchUrl` without `canLaunchUrl` gate, with `try/catch`, fallback to `LaunchMode.platformDefault`, show `SnackBar` on failure. Add Android `AndroidManifest.xml` `<queries>` for https if missing, check `mobile/android/app/src/main/AndroidManifest.xml`. Also add `http` scheme fallback. File: `mobile/lib/ui/features/donate/views/donate_screen.dart`, `mobile/android/app/src/main/AndroidManifest.xml`. | ✅ | 2026-09-11 |
| TASK-005 | Same hardening for `AboutScreen._openRepo` for consistency. | ✅ | 2026-09-11 |

### Phase 3 — Settings → Driving wiring (REQ-004, REQ-005, REQ-006)

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-006 | Make `GamePreset` override-aware: create `BindingRepository` (`SharedPreferences` key `wheeldeck.binding.<control>.<keyboard|gamepad>`) or extend `SettingsRepository` with `getBindingOverride`/`setBindingOverride`/`clearOverrides`. Update `GamePreset.bindingFor` to check override first, or have `SettingsViewModel` expose `bindingFor(ControlId)` that merges preset + overrides. Wire `_editBinding` to persist and `notifyListeners` so chip updates immediately. Files: `mobile/lib/data/repositories/settings_repository.dart`, `mobile/lib/data/services/controller_preset.dart` or new `binding_repository.dart`, `mobile/lib/ui/features/settings/view_models/settings_view_model.dart`. | ✅ | 2026-09-11 |
| TASK-007 | Wire Controller Type to Driving visuals: expose `ControllerType` in `DrivingViewModel` (load via `ControllerType.load()` in `init` + `refreshControllerType()`). In `DrivingView._buildDrivingContent`, conditionally show/hide `PedalPanel` and `DashboardPanel` per `controllerType` (steeringOnly → wheel only, steeringDashboard → no pedals, etc.). Ensure `WheelView` stays. Files: `mobile/lib/ui/features/driving/view_models/driving_view_model.dart`, `mobile/lib/ui/features/driving/views/driving_view.dart`. | ✅ | 2026-09-11 |
| TASK-008 | Make Pedal Layout live: after Settings pop, refresh Driving. Add `DrivingView.didChangeDependencies` or handle `Navigator.push(...).then((_) => _viewModel.refreshPedalLayout())` from Menu/Driving when Settings returns. Already have `refreshPedalLayout()` but never called; wire it. Also handle `ControllerType` refresh similarly. File: `mobile/lib/ui/features/driving/views/driving_view.dart`. | ✅ | 2026-09-11 |
| TASK-009 | Fix Reset clipping in portrait: wrap `SettingsScreen` `ListView` bottom in `SafeArea` + extra bottom padding (`80` for FAB clearance style) or move Reset into `bottomNavigationBar` with `SafeArea`. Verify portrait 360dp and landscape. File: `mobile/lib/ui/features/settings/views/settings_screen.dart`. | ✅ | 2026-09-11 |

## 3. Alternatives

- **ALT-001** Replace `_Routing` with `go_router` + `ShellRoute` for Menu/Connect/Driving — rejected for fix scope; `_Routing` + explicit `Navigator` is sufficient and lower risk.
- **ALT-002** Store per-control bindings in a single JSON blob vs per-key `SharedPreferences` entries — either works; per-key is simpler to clear per control, blob is one read. Choose per-key for incremental reset.
- **ALT-004** Fix Reset clipping by constraining `ListView` inside `Expanded` + `SingleChildScrollView` — overkill; `SafeArea` + bottom padding or `bottomNavigationBar` is the stdlib fix.

## 4. Dependencies

- **DEP-001** `url_launcher` already present — just needs hardening + manifest queries.
- **DEP-002** `shared_preferences` already present — used for binding overrides.

## 5. Files

- **FILE-001** `mobile/lib/ui/features/connection/views/connection_screen.dart` — add Ready-to-Drive CTA
- **FILE-002** `mobile/lib/ui/features/driving/views/driving_view.dart` — fix disconnect destination, add recalibrate refresh wiring
- **FILE-003** `mobile/lib/ui/features/driving/view_models/driving_view_model.dart` — add `controllerType`, `refreshControllerType`, expose for Driving visuals
- **FILE-004** `mobile/lib/ui/features/donate/views/donate_screen.dart` — harden `_open`
- **FILE-005** `mobile/lib/ui/features/about/views/about_screen.dart` — same hardening
- **FILE-006** `mobile/android/app/src/main/AndroidManifest.xml` — add `<queries>` if missing
- **FILE-007** `mobile/lib/data/repositories/settings_repository.dart` — add binding override get/set/clear
- **FILE-008** `mobile/lib/data/services/binding_repository.dart` (or extend existing) — override storage
- **FILE-009** `mobile/lib/ui/features/settings/view_models/settings_view_model.dart` — merge overrides, persist on edit, notify
- **FILE-010** `mobile/lib/ui/features/settings/views/settings_screen.dart` — wire overrides, SafeArea for Reset
- **FILE-011** `mobile/test/ui/features/connection/connection_screen_test.dart` — add Ready-to-Drive CTA test
- **FILE-012** `mobile/test/ui/features/donate/donate_screen_test.dart` — new url_launcher mock test (optional)
- **FILE-013** `mobile/test/ui/features/settings/settings_screen_test.dart` — add binding edit + reset clipping test
- **FILE-014** `TODO.md` — mark new problems checklist as in-progress/done per phase
- **FILE-015** `plan/fix-mobile-revamp-followup-1.md` — this plan

## 6. Testing

- **TEST-001** `connection_screen_test` — after `status==connected`, `Ready to Drive` CTA visible and navigates to `DrivingView` without Back.
- **TEST-002** `driving_view_test` — tap Disconnect → `ConnectionScreen` visible, not `MenuScreen`.
- **TEST-003** `donate_screen_test` — mock `url_launcher` platform, tap Open → `launchUrl` called; failure shows SnackBar.
- **TEST-004** `settings_view_model_test` — edit binding persists and `bindingFor` returns override; `resetToDefaults` clears overrides.
- **TEST-005** `driving_view_test` — change `ControllerType`/`PedalLayout` in Settings then return → `PedalPanel` order/visibility updates.
- **TEST-006** `settings_screen_test` — Reset button fully visible in portrait 360x800 (no clipping), `find.byType(OutlinedButton)` hit-test.
- **MANUAL-001** Android: connect → Ready to Drive → Driving appears; Driving → Disconnect → Connect page.
- **MANUAL-002** Donate Open on Android 13+ (with queries) and iOS opens externally.
- **MANUAL-003** Settings → change Controller Type/Pedal Layout → back to Driving → pedals/dashboard visibility changes immediately.
- **MANUAL-004** Portrait: Settings Reset button fully visible, not cut 50%.

## 7. Risks & Assumptions

- **RISK-001** `_Routing` + pushed `ConnectionScreen` can show Driving underneath if status flips while Connection is on stack — need explicit pop before Driving to avoid double Driving. Mitigation: use `pushReplacement` or `pop` then let `_Routing` drive.
- **RISK-002** `url_launcher` `canLaunchUrl` false on some OEMs even when browser exists — mitigation: try `launchUrl` regardless and catch.
- **ASSUMPTION-001** `feature/revamp-mobile-ui` (PR #27 c256364) is on `main` — this branch rebases off that.

## 8. Related Specifications / Further Reading

- `TODO.md` — source of the 7 problems
- `mobile/lib/main.dart:44` — `_Routing` logic
- `mobile/lib/ui/features/connection/views/connection_screen.dart` — current status card + discovery
- `mobile/lib/ui/features/driving/views/driving_view.dart` — current recalibrate + lifecycle
- `mobile/lib/ui/features/donate/views/donate_screen.dart` — current `_open`
- `mobile/lib/ui/features/settings/views/settings_screen.dart` — current bindings + reset
- `desktop/WheelDeck.Core/Input/InputMapper.cs` — ETS2 preset source
- `plan/feature-revamp-mobile-ui-1.md` — original revamp plan (Phases 0-5)
