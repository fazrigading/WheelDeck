---
goal: Build WheelDeck v1 from the docs (protocol schemas, desktop server, mobile app)
version: 1.0
date_created: 2026-09-03
last_updated: 2026-09-03
owner: fazrigading
status: Planned
tags: [feature, architecture, mobile, desktop, protocol, v1]
---

# Introduction

![Status: Planned](https://img.shields.io/badge/status-Planned-blue)

Turn the four docs in `docs/` into working v1 code: shared protocol schemas, a .NET/Avalonia desktop server, and a Flutter mobile app. Build bottom-up so each phase's outputs feed the next. Each phase maps to one GitHub issue in `fazrigading/WheelDeck`.

## 1. Requirements & Constraints

- **REQ-001**: Control enums and message shapes come from `protocol/schema/` as the single source of truth, matching `backend-interface.md` and `mobile-interface.md`.
- **REQ-002**: The desktop exposes a `VirtualOutputBackend` interface with `initialize`, `setAxis`, `setButton`, `sendKey`, `neutralize`, and `shutdown`.
- **REQ-003**: `PairingManager` enforces a 30-day inactivity expiry and a gate that only the active, non-expired, non-revoked device reaches the input mapper.
- **REQ-004**: `neutralize()` runs on WebSocket disconnect, heartbeat timeout (2 missed beats), active-device switch, and server shutdown.
- **REQ-005**: The mobile app captures steering, pedals, and dashboard controls and sends state/button messages over WebSocket.
- **REQ-006**: Pairing persists across sessions until the desktop's 30-day expiry; session tokens skip re-pairing.
- **REQ-007**: Input latency targets sub-50ms round trip.
- **CON-001**: Windows backend uses ViGEmBus and SendInput; Linux backend uses uinput.
- **CON-002**: Desktop UI is Avalonia (C#/.NET); mobile UI is Flutter (Dart).
- **CON-003**: Primary transport is local Wi-Fi; USB tethering is the fallback.
- **CON-004**: v1 targets ETS2 only; macOS, Bluetooth, and force feedback are post-v1.
- **GUD-001**: Keep folder names identical to the layer names in `mobile-interface.md` and `project-structure.md`.
- **GUD-002**: Prefer plain speech and active voice in code comments and docs, matching the unslop rewrite.
- **PAT-001**: Separate backend projects per platform (`Windows/`, `Linux/`) behind one interface.
- **PAT-002**: Monorepo, one PR per cross-component change.

## 2. Implementation Steps

### Implementation Phase 1: Protocol schemas

- GOAL-001: Define the shared JSON schemas as the single source of truth for control enums and message shapes.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-001 | Create `protocol/schema/controls.json` with `ControlId` and `ActionType` enums. | ✅ | 2026-09-03 |
| TASK-002 | Create `protocol/schema/state_message.json` with `type`, `seq`, `steering`, `accelerator`, `brake`, `clutch`. | ✅ | 2026-09-03 |
| TASK-003 | Create `protocol/schema/button_message.json` with `type`, `control`, `action`. | ✅ | 2026-09-03 |
| TASK-004 | Create `protocol/schema/session_messages.json` with `pair_request`, `pair_response`, `heartbeat`, `device_switch`. | ✅ | 2026-09-03 |

### Implementation Phase 2: Repository scaffolding

- GOAL-002: Wire the repo to GitHub, add gitignore and README, and scaffold the Flutter and .NET skeletons.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-005 | Add git remote `origin` pointing to `https://github.com/fazrigading/WheelDeck.git`. | ✅ | 2026-09-03 |
| TASK-006 | Write `.gitignore` covering Flutter, .NET, and IDE artifacts. | ✅ | 2026-09-03 |
| TASK-007 | Write `README.md` with a short description and pointer to `docs/`. | ✅ | 2026-09-03 |
| TASK-008 | Create directory layout and scaffold `mobile/pubspec.yaml` and `desktop/WheelDeck.sln`. | ✅ | 2026-09-03 |

### Implementation Phase 3: Desktop core

- GOAL-003: Build the protocol models, virtual output interface, pairing manager, and input mapper.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-009 | Add protocol model classes in `desktop/WheelDeck.Core/` referenced from `protocol/schema/`. | ✅ | 2026-09-03 |
| TASK-010 | Define `VirtualOutputBackend` and `AxisType` in `desktop/WheelDeck.Core/`. | ✅ | 2026-09-03 |
| TASK-011 | Implement `PairingManager` with `generatePairingCode`, `validatePairing`, `listPairedDevices`, `setActiveDevice`, `revokeDevice`, `isExpired`, `touchLastSeen`, and `PairedDevice`. | ✅ | 2026-09-03 |
| TASK-012 | Implement `InputMapper` to route axes and buttons per mapping mode, default simulated key presses. | ✅ | 2026-09-03 |

### Implementation Phase 4: Desktop virtual output backends

- GOAL-004: Implement the Windows and Linux backends behind `VirtualOutputBackend`.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-013 | Implement ViGEmBus virtual Xbox controller in `desktop/WheelDeck.Backends/Windows/`. | ✅ | 2026-09-03 |
| TASK-014 | Implement SendInput key simulation in the Windows backend. | ✅ | 2026-09-03 |
| TASK-015 | Implement uinput virtual joystick in `desktop/WheelDeck.Backends/Linux/`. | ✅ | 2026-09-03 |
| TASK-016 | Implement `neutralize()` on both backends to zero axes and release buttons/keys. | ✅ | 2026-09-03 |

### Implementation Phase 5: Desktop network/session layer

- GOAL-005: Add the WebSocket listener, pairing flow, heartbeat, and device-selection enforcement.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-017 | Implement WebSocket-over-TCP listener for `state` and `button` messages. | ✅ | 2026-09-03 |
| TASK-018 | Implement pairing flow with `pair_request`/`pair_response` and session token persistence. | ✅ | 2026-09-03 |
| TASK-019 | Implement heartbeat every ~2s with neutralize after 2 missed beats. | ✅ | 2026-09-03 |
| TASK-020 | Enforce the active/non-expired/non-revoked gate before messages reach `InputMapper`. | ✅ | 2026-09-03 |

### Implementation Phase 6: Desktop app (Avalonia UI)

- GOAL-006: Build the Avalonia composition root and connection/pairing/setup UI.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-021 | Add composition root in `desktop/WheelDeck.App/` that picks the backend by OS. | ✅ | 2026-09-03 |
| TASK-022 | Build connection management UI (status, active device, firewall reminder). | | |
| TASK-023 | Build pairing UI (PIN/QR, paired list, revoke, set active). | | |
| TASK-024 | Add first-run setup check for ViGEmBus or uinput permissions. | | |
| TASK-025 | Add manual launch default and opt-in daemon mode. | | |

### Implementation Phase 7: Mobile input capture layer

- GOAL-007: Capture and normalize steering, pedals, and dashboard input.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-026 | Implement `SteeringSensor` in `mobile/lib/input/steering_sensor.dart`. | | |
| TASK-027 | Implement `PedalInput` and `PedalType` in `mobile/lib/input/pedal_input.dart`. | | |
| TASK-028 | Implement `DashboardInput` and control/action enums in `mobile/lib/input/dashboard_input.dart`. | | |

### Implementation Phase 8: Mobile network client layer

- GOAL-008: Talk to the desktop over WebSocket with discovery, pairing, and heartbeat.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-029 | Implement `WheelDeckClient` in `mobile/lib/network/wheeldeck_client.dart`. | | |
| TASK-030 | Implement mDNS discovery and manual IP fallback in `mobile/lib/network/discovery.dart`. | | |
| TASK-031 | Implement pairing flow and session-token storage in `mobile/lib/network/pairing.dart`. | | |
| TASK-032 | Implement heartbeat and auto-reconnect, sending `sendState()` on every tick. | | |

### Implementation Phase 9: Mobile UI layer

- GOAL-009: Build the wheel, pedals, dashboard, and connection screens.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-033 | Build the wheel view driven by `onAngleChanged`. | | |
| TASK-034 | Build vertical draggable pedal bars with spring-back release. | | |
| TASK-035 | Build the truck-styled dashboard control panel. | | |
| TASK-036 | Build connection and pairing screens (discovery, manual entry, PIN/QR, status). | | |

### Implementation Phase 10: Mobile lifecycle, orientation, calibration

- GOAL-010: Handle orientation lock, OS lifecycle pauses, calibration, and permissions.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-037 | Lock device orientation during driving sessions. | | |
| TASK-038 | Pause input on call/lock/background and require calibration re-confirm on resume. | | |
| TASK-039 | Add calibration UI to set the straight-ahead center. | | |
| TASK-040 | Add onboarding and permission prompts for motion sensor and local network. | | |

### Implementation Phase 11: Setup scripts

- GOAL-011: Ship first-run setup scripts for both platforms.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-041 | Write `scripts/linux/install-uinput-rules.sh` with Fedora SELinux handling. | | |
| TASK-042 | Write `scripts/windows/check-vigembus.ps1`. | | |

### Implementation Phase 12: CI workflows

- GOAL-012: Add mobile and desktop CI.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-043 | Populate `.github/workflows/mobile-ci.yml` for Flutter build/test. | | |
| TASK-044 | Populate `.github/workflows/desktop-ci.yml` for .NET build/test. | | |

### Implementation Phase 13: Testing and validation

- GOAL-013: Verify the build, run unit/widget tests, and do a manual E2E smoke test.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-045 | Add unit tests for protocol models, `PairingManager`, and `InputMapper`. | | |
| TASK-046 | Add Flutter widget tests for pedals, wheel, dashboard, and connection screens. | | |
| TASK-047 | Add .NET tests for `neutralize()` on all four call sites. | | |
| TASK-048 | Run manual E2E in ETS2 and verify tethering fallback and sub-50ms latency. | | |

## 3. Alternatives

- **ALT-001**: Split repos per component instead of a monorepo. Rejected: cross-component changes would span multiple PRs.
- **ALT-002**: One backend project with runtime OS checks. Rejected: a per-platform folder makes adding macOS later a new folder, not a rewrite.
- **ALT-003**: Exponential backoff for reconnection. Rejected: fixed interval is fine for LAN-only v1.

## 4. Dependencies

- **DEP-001**: .NET SDK with Avalonia UI.
- **DEP-002**: Flutter SDK.
- **DEP-003**: ViGEmBus driver (Windows) and uinput (Linux).
- **DEP-004**: `gh` CLI authenticated against `fazrigading/WheelDeck`.
- **DEP-005**: `create-implementation-plan` and `create-github-issues-feature-from-implementation-plan` skills.

## 5. Files

- **FILE-001**: `protocol/schema/controls.json`
- **FILE-002**: `protocol/schema/state_message.json`
- **FILE-003**: `protocol/schema/button_message.json`
- **FILE-004**: `protocol/schema/session_messages.json`
- **FILE-005**: `.gitignore`
- **FILE-006**: `README.md`
- **FILE-007**: `mobile/pubspec.yaml`
- **FILE-008**: `desktop/WheelDeck.sln`
- **FILE-009**: `desktop/WheelDeck.Core/**`
- **FILE-010**: `desktop/WheelDeck.Backends/Windows/**`
- **FILE-011**: `desktop/WheelDeck.Backends/Linux/**`
- **FILE-012**: `desktop/WheelDeck.App/**`
- **FILE-013**: `mobile/lib/input/**`
- **FILE-014**: `mobile/lib/network/**`
- **FILE-015**: `mobile/lib/ui/**`
- **FILE-016**: `scripts/linux/install-uinput-rules.sh`
- **FILE-017**: `scripts/windows/check-vigembus.ps1`
- **FILE-018**: `.github/workflows/mobile-ci.yml`
- **FILE-019**: `.github/workflows/desktop-ci.yml`

## 6. Testing

- **TEST-001**: Protocol models serialize/deserialize matching schema constraints.
- **TEST-002**: `PairingManager` expires devices after 30 days and revokes on demand.
- **TEST-003**: `InputMapper` routes axes and buttons per mapping mode.
- **TEST-004**: `neutralize()` zeroes axes and releases buttons on all four call sites.
- **TEST-005**: Flutter widget tests for wheel, pedals, dashboard, and connection screens.
- **TEST-006**: Manual E2E: pair, drive in ETS2, verify tethering fallback and latency.

## 7. Risks & Assumptions

- **RISK-001**: Touch-based analog pedals may not feel as controllable as a real pedal.
- **RISK-002**: Gyroscope drift and calibration vary by phone hardware.
- **RISK-003**: Fedora SELinux may block uinput without extra policy.
- **ASSUMPTION-001**: `gh` is authenticated and can create issues in `fazrigading/WheelDeck`.
- **ASSUMPTION-002**: The `.NET` and `Flutter` SDKs are available in CI and locally.

## 8. Related Specifications / Further Reading

- `docs/prd.md`
- `docs/backend-interface.md`
- `docs/mobile-interface.md`
- `docs/project-structure.md`
