# WheelDeck Docs

Specifications, architecture decisions, and developer guides for the WheelDeck project.

## Contents

### Specifications

| File | Description |
|------|-------------|
| `prd.md` | Product requirements — goals, target user, platforms, feature list |
| `backend-interface.md` | Desktop server interface spec — wire protocol, PairingManager, VirtualOutputBackend, neutralize() call sites |
| `mobile-interface.md` | Mobile app interface spec — three-layer architecture, input capture, network client, UI layer |
| `project-structure.md` | Repository layout and rationale for every top-level directory |

### Developer guides

| File | Description |
|------|-------------|
| `desktop-dev-guide.md` | Desktop setup, build, test, platform-specific config, adding controls |
| `mobile-dev-guide.md` | Mobile setup, build, test, onboarding, adding controls |

### Architecture Decision Records

| File | Decision |
|------|----------|
| `adr/0001-neutralize-on-device-switch.md` | neutralize() fires before the new device is authorized |
| `adr/0002-fixed-reconnect-interval.md` | Fixed reconnect interval over exponential backoff |
| `adr/0003-standalone-heartbeat.md` | Heartbeat runs independently of state messages |
| `adr/0004-degraded-continue-setup-check.md` | Setup check warns but does not block startup |
| `adr/0005-setup-scripts-detect-only.md` | Setup scripts detect issues and print instructions, never modify system |

## Protocol schemas

Shared JSON schemas live in `protocol/schema/` — the single source of truth for all message formats and control enums:

| File | Purpose |
|------|---------|
| `controls.json` | ControlId and ActionType enums |
| `state_message.json` | Continuous steering/pedal input message |
| `button_message.json` | Discrete dashboard control event |
| `session_messages.json` | Pairing, heartbeat, device switch messages |
