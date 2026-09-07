---
goal: Display desktop IP address and port alongside PIN so mobile connection uses consistent pairing flow
version: 1.0
date_created: 2026-09-07
last_updated: 2026-09-07
owner: fazrigading
status: Planned
tags:
  - feature
  - ux
  - connection
---

# Introduction

![Status: Planned](https://img.shields.io/badge/status-Planned-blue)

The desktop app generates a 6-digit PIN for pairing, but the mobile app requires manual IP and port entry to connect. The desktop does not display its own IP address, so mobile users have no way to know where to connect without guessing. Additionally, mDNS discovery is non-functional — the mobile queries `_wheeldeck._tcp.local` but the desktop has no mDNS advertiser. This plan unifies the connection flow by having the desktop display its local IP address, port, and pairing PIN in one place, giving mobile users all the information they need.

## 1. Requirements & Constraints

- **REQ-001**: Desktop must display its local network IP address on the Connection screen
- **REQ-002**: Desktop must display the listening port alongside the IP address
- **REQ-003**: Desktop must display the pairing PIN on the same screen as the IP/port
- **REQ-004**: IP address must update dynamically if the network interface changes while the app is running
- **REQ-005**: Mobile flow remains unchanged — discover via mDNS (if available) or enter IP manually, then enter PIN
- **CON-001**: WebSocket listener binds to `http://+:{port}/` (all interfaces) — IP detection must enumerate network interfaces, not read from the listener
- **CON-002**: Desktop targets Windows and Linux only — IP detection must use cross-platform .NET APIs
- **GUD-001**: Follow existing MVVM pattern — IP/port state lives in `ConnectionViewModel`, displayed in `ConnectionView.axaml`
- **PAT-001**: Use `System.Net.NetworkInformation.NetworkInterface.GetAllNetworkInterfaces()` for IP enumeration (standard .NET, no new dependencies)

## 2. Implementation Steps

### Implementation Phase 1

- GOAL-001: Add local IP address detection to the desktop ConnectionViewModel

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-001 | Create a static helper method `GetLocalIpAddress()` in `ConnectionViewModel.cs` that enumerates active, non-loopback IPv4 addresses via `NetworkInterface.GetAllNetworkInterfaces()` and returns the first suitable address (preferring addresses in 192.168.x.x or 10.x.x.x ranges). Return `"Unknown"` if no suitable address is found. | | |
| TASK-002 | Add a `string LocalIpAddress` property with backing field and change notification to `ConnectionViewModel.cs`. Initialize it in the constructor by calling `GetLocalIpAddress()`. | | |
| TASK-003 | Add a read-only `string ConnectionInfo` property to `ConnectionViewModel.cs` that formats the display string as `"{LocalIpAddress}:{Port}"`. Update when `Port` or `LocalIpAddress` changes. | | |
| TASK-004 | Modify `UpdateFrom()` in `ConnectionViewModel.cs:47` to also refresh `LocalIpAddress` by calling `GetLocalIpAddress()` each time the server status updates. | | |

### Implementation Phase 2

- GOAL-002: Display IP address and port on the desktop ConnectionView

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-005 | Add a `StackPanel` row to `ConnectionView.axaml` between the "Status" and "Active device" rows showing `"Address: {Binding ConnectionInfo}"` with the same horizontal layout pattern as existing rows. | | |

### Implementation Phase 3

- GOAL-003: Display PIN alongside IP on the PairingView with connection context

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-006 | Add `string LocalIpAddress` and `string ConnectionInfo` properties to `PairingViewModel.cs` mirroring `ConnectionViewModel`. Pass the IP from `PairingView` constructor or fetch it directly in `PairingViewModel` using the same `GetLocalIpAddress()` logic. | | |
| TASK-007 | Add a `TextBlock` to `PairingView.axaml` below the "Enter this code on the phone" line: `"Connect to {Binding ConnectionInfo} and enter the code above."` This gives the user a single screen with both the target address and the pairing code. | | |
| TASK-008 | Move `GetLocalIpAddress()` to a shared static helper class `NetworkHelper.cs` in `WheelDeck.Core/Network/` so both `ConnectionViewModel` and `PairingViewModel` can call it without duplication. | | |

### Implementation Phase 4

- GOAL-004: Add unit test for IP detection helper

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-009 | Add a test in `desktop/WheelDeck.Tests/` verifying `NetworkHelper.GetLocalIpAddress()` returns a non-null, non-empty string (or `"Unknown"`) — confirms the method runs without throwing on the test host. | | |

## 3. Alternatives

- **ALT-001**: Add mDNS advertiser to the desktop so mobile auto-discovers it — rejected because it requires a new dependency (e.g., `Zeroconf` or `Mono.Zeroconf`) and mDNS is unreliable on many networks. Manual IP + PIN is simpler and more reliable.
- **ALT-002**: Embed the IP address in the pairing code itself (e.g., encode IP into a QR code) — rejected because it couples connection and pairing into one step, breaking the existing flow where discovery and pairing are separate concerns.
- **ALT-003**: Broadcast the IP via UDP to the mobile app — rejected because it requires a listener on the mobile side and adds protocol complexity for a problem that a static display solves.

## 4. Dependencies

- **DEP-001**: `System.Net.NetworkInformation` — built into .NET, no NuGet install needed
- **DEP-002**: Existing `ConnectionViewModel` and `PairingViewModel` classes — already in the codebase

## 5. Files

- **FILE-001**: `desktop/WheelDeck.App/ViewModels/ConnectionViewModel.cs` — add IP detection and ConnectionInfo property
- **FILE-002**: `desktop/WheelDeck.App/Views/ConnectionView.axaml` — add address display row
- **FILE-003**: `desktop/WheelDeck.App/ViewModels/PairingViewModel.cs` — add IP detection for pairing screen
- **FILE-004**: `desktop/WheelDeck.App/Views/PairingView.axaml` — add connection info text
- **FILE-005**: `desktop/WheelDeck.Core/Network/NetworkHelper.cs` — new shared IP detection helper
- **FILE-006**: `desktop/WheelDeck.Tests/NetworkHelperTests.cs` — new test file

## 6. Testing

- **TEST-001**: Unit test that `NetworkHelper.GetLocalIpAddress()` returns a string (may be `"Unknown"` in CI) without throwing
- **TEST-002**: Manual test: launch desktop on Windows, verify ConnectionView shows a valid local IP (e.g., `192.168.1.x`)
- **TEST-003**: Manual test: launch desktop on Linux, verify ConnectionView shows a valid local IP
- **TEST-004**: Manual test: generate pairing code on PairingView, verify connection info text displays below the code
- **TEST-005**: Manual test: connect from mobile using the displayed IP and PIN, verify successful pairing

## 7. Risks & Assumptions

- **RISK-001**: Machine has multiple active network interfaces — `GetLocalIpAddress()` returns the first suitable one; user may need to match the interface their phone is on. Mitigation: sort by interface type (prefer Wi-Fi/Ethernet over virtual adapters).
- **RISK-002**: IP address changes while app is running (e.g., DHCP renewal, VPN connect/disconnect) — `UpdateFrom()` refreshes on server events but not on network change events. Acceptable for v1; can add `NetworkAddressChanged` listener later if needed.
- **ASSUMPTION-001**: The WebSocket listener binds to all interfaces (`http://+:{port}/`), so any local IP shown is reachable from the phone on the same network
- **ASSUMPTION-002**: Mobile user and desktop are on the same LAN subnet (standard home network topology)

## 8. Related Specifications / Further Reading

- `docs/prd.md` — Product requirements mentioning mDNS discovery and manual IP fallback
- `spec/mobile-onboarding-flow.md` — Mobile onboarding spec
- `mobile/lib/network/discovery.dart` — Mobile mDNS discovery implementation
