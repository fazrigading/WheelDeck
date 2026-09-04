# Mobile Onboarding Flow — Spec

## Problem Statement

The WheelDeck mobile app has working driving views (wheel, pedals, dashboard) and a connection screen, but they exist as isolated widgets with no orchestration. A new user opening the app sees "Hello World" — there's no flow to guide them through permissions, connection, pairing, calibration, and into driving. There's also no handling for orientation changes or OS lifecycle events (calls, screen lock, backgrounding), which can leave stale input stuck or invalidate calibration.

## Solution

Build a multi-step onboarding flow that guides the user from first launch through permissions → discovery/pairing → calibration → driving. Once connected and calibrated, the app transitions to the driving view with orientation locked. On background/lock/call, input pauses and calibration must be reconfirmed before resuming.

## User Stories

1. As a first-time user, I want the app to prompt me for motion sensor and local network permissions with clear explanations, so I understand why each is needed before driving.

2. As a first-time user, I want a step-by-step flow that takes me from permissions through connection, pairing, and calibration, so I'm not overwhelmed with everything at once.

3. As a user connecting for the first time, I want to see discovered desktops or enter an IP manually, so I can reach my server even on networks that block mDNS.

4. As a user pairing a new desktop, I want to enter the PIN shown on the desktop, so the desktop trusts my phone.

5. As a returning user with a saved session token, I want the app to skip pairing automatically, so I can get into driving faster.

6. As a user who has never calibrated, I want to set my "straight ahead" orientation before driving, so steering feels correct in-game.

7. As a user receiving a phone call mid-drive, I want the app to stop sending input immediately, so my truck doesn't accelerate into a wall.

8. As a user returning from a call or unlocking my screen, I want to confirm my phone's orientation before resuming, so steering doesn't pull to one side.

9. As a user rotating my phone during driving, I want the UI to stay in its current orientation, so the gyroscope mapping stays predictable.

10. As an iOS PWA user, I want the app to reconnect automatically when I bring it back to the foreground after Safari suspended it, so I don't have to re-enter the connection flow.

## Implementation Decisions

### Onboarding flow as a single stateful widget

The app needs a top-level stateful widget that orchestrates the linear flow. Existing views (`ConnectionScreen`, `CalibrationView`, `WheelView`, `PedalPanel`, `DashboardPanel`) are reused as-is — only the orchestrator is new.

The flow order, validated during grilling:
1. Permission prompts (motion sensor, local network)
2. Discovery / manual IP entry (existing `ConnectionScreen`)
3. PIN entry if pairing required (existing `ConnectionScreen` handles this)
4. Calibration confirm (existing `CalibrationView`)
5. Driving view (existing wheel + pedals + dashboard)

Each step validates before advancing. Back navigation is allowed between steps.

### Orientation lock scope

Orientation locks only when entering a driving view. The connection and calibration screens allow orientation flexibility — the user may hold the phone any way while setting up. The lock captures whatever orientation is current when driving starts; it does not force landscape.

Use `SystemChrome.setPreferredOrientations` with the current orientation when transitioning to driving, and reset to all orientations when leaving driving.

### Lifecycle pause behavior

Subscribe to `WidgetsBindingObserver` at the orchestrator level. On `AppLifecycleState.paused` or `AppLifecycleState.inactive`:
- Stop the `SteeringSensor`
- Cancel pedal release timers
- Do NOT disconnect the WebSocket (allows fast reconnect)

On `AppLifecycleState.resumed`:
- Show calibration reconfirm screen before returning to driving
- Always prompt regardless of detected drift (decision: drift detection adds complexity for little gain)

### Permission prompting

Use the `permission_handler` package (to be added to pubspec). Prompts are non-blocking — the flow continues even if denied, but surfaces a warning that the feature won't work. Motion sensor is required for steering; local network is required for discovery (manual IP entry still works without it).

### Main app entry point

Replace the placeholder `MainApp` with the onboarding orchestrator. The orchestrator owns the `WheelDeckClient`, `PairingController`, `ServerDiscovery`, `SteeringSensor`, `PedalInput`, and `DashboardInput` instances and passes them down to child views.

### No new seams for existing functionality

`ConnectionScreen`, `CalibrationView`, and the driving widgets are unchanged. The orchestrator composes them. The only new seam is the orchestrator itself and a small permissions helper.

## Testing Decisions

### What to test

Test external behavior, not implementation details:
- The flow advances through steps in order
- The flow blocks advancement when prerequisites aren't met (no permissions → warning)
- Orientation lock engages on driving entry and releases on exit
- Lifecycle pause stops sensor and pedal input
- Lifecycle resume triggers calibration reconfirm before driving resumes

### How to test

Use existing patterns from the codebase:
- `testWidgets` for widget tests (matches existing UI tests)
- `fake_async` for timer-based tests (matches existing heartbeat test)
- Injected `connect` callback for `WheelDeckClient` to avoid real sockets
- `_MemoryStore` or fakes for `SessionTokenStore`
- `_fakeDiscovery` for `ServerDiscovery` (matches existing pattern)

### Test files to add

- `test/ui/onboarding_flow_test.dart` — orchestrator behavior, step transitions, lifecycle handling
- `test/ui/orientation_lock_test.dart` — orientation lock engagement/release (may need platform channel mocking)
- Updated `test/network/heartbeat_test.dart` — remove the obsolete "resends last state" test that no longer matches the standalone-heartbeat decision

### Prior art

- `connection_screen_test.dart` demonstrates widget testing with injected dependencies
- `heartbeat_test.dart` demonstrates `fake_async` for timer-based testing
- `calibration_view_test.dart` demonstrates testing a simple stateless view

## Out of Scope

- QR pairing — stubbed for v1 (PIN only)
- Bluetooth transport — post-v1
- Multiple saved profiles or per-game remapping — non-goal per PRD
- macOS desktop support — post-v1
- Force feedback / rumble — post-v1
- iOS PWA-specific disconnect handling beyond auto-reconnect — covered by existing `WheelDeckClient` behavior
- Settings screen for sensitivity/calibration tuning — exists in views but not part of this flow spec

## Further Notes

- The `WheelDeckClient` was just fixed: heartbeat is now standalone (no state resend) and `_lastState` was removed. The existing heartbeat test `'resends the last state on each heartbeat tick'` must be deleted as it tests removed behavior.
- This spec covers TASK-036 through TASK-040 from the implementation plan.
- ADR-0003 (standalone heartbeat) and ADR-0004 (degraded-continue setup check) are relevant to this work.
- `permission_handler` is a new dependency to be added to `pubspec.yaml`.
