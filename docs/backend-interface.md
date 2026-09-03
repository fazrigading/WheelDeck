# WheelDeck desktop backend interface specification

## Overview

This document specifies the interfaces used by the WheelDeck desktop server: the wire protocol between mobile app and desktop, the pairing/session layer, and the virtual output backend abstraction that makes Windows and Linux support interchangeable at the input-mapping layer.

## Architecture

```
Mobile App
   |  (WebSocket, JSON messages)
   v
Network/Session Layer   -> pairing, auth, device selection, heartbeat
   v
Input Mapper            -> interprets messages, applies per-control mapping mode
   v
Virtual Output Backend  -> OS-specific: ViGEmBus (Windows) / uinput (Linux)
```

## 1. Wire protocol

Transport: WebSocket over TCP. A single authenticated connection carries both continuous state and discrete button events. No separate UDP channel in v1.

### 1.1 Continuous state message

Sent on every sensor/touch update. Latest value wins. No acknowledgment required.

```json
{
  "type": "state",
  "seq": 4821,
  "steering": 0.42,
  "accelerator": 0.85,
  "brake": 0.0,
  "clutch": 0.0
}
```

| Field | Type | Range | Notes |
|---|---|---|---|
| seq | integer | monotonic | used to detect/discard out-of-order packets |
| steering | float | -1.0 to 1.0 | 0 = center |
| accelerator | float | 0.0 to 1.0 | pedal pressure |
| brake | float | 0.0 to 1.0 | pedal pressure |
| clutch | float | 0.0 to 1.0 | pedal pressure |

### 1.2 Discrete button event

Requires reliable delivery, which TCP provides.

```json
{
  "type": "button",
  "control": "turn_signal_left",
  "action": "toggle"
}
```

action values by control type:

| Action | Used for |
|---|---|
| toggle | turn signals, headlights, cruise on/off |
| press / release | parking brake (if held), wipers (if press-and-hold) |
| hold_confirm | engine start (deliberate two-step action) |

### 1.3 Control enum

```
ParkingBrake
TurnSignalLeft
TurnSignalRight
HeadlightToggle
HighBeamToggle
Wipers
CruiseToggle
CruiseSetResume
EngineStart
```

### 1.4 Session messages

| Message | Direction | Purpose |
|---|---|---|
| pair_request | phone -> desktop | initiates pairing, includes entered PIN or scanned QR token |
| pair_response | desktop -> phone | accept/reject pairing |
| heartbeat | both | sent every ~2s; desktop neutralizes output after 2 missed beats |
| device_switch | desktop -> phone | tells a phone it is no longer the active device |

## 2. Pairing / session interface (desktop-side)

```
interface PairingManager {
    generatePairingCode(): PairingCode
    validatePairing(deviceId: string, code: string): PairingResult
    listPairedDevices(): PairedDevice[]
    setActiveDevice(deviceId: string): void
    revokeDevice(deviceId: string): void
    isExpired(device: PairedDevice): bool   // true if lastSeenAt > 30 days ago
    touchLastSeen(deviceId: string): void   // called on every heartbeat
}

struct PairedDevice {
    id: string
    displayName: string
    pairedAt: timestamp
    lastSeenAt: timestamp
    isActive: bool
}
```

### Enforcement rule

No state or button message reaches the Input Mapper unless it originates from the currently active, non-expired, non-revoked device. This is the single point where the "public space, untrusted network" safety requirement from the PRD is enforced. Do not duplicate this check elsewhere.

## 3. Virtual output backend interface

Identical interface across platforms. Implementation differs per OS.

```
interface VirtualOutputBackend {
    initialize(): Result
    setAxis(axis: AxisType, value: float)         // steering: -1..1, pedals: 0..1
    setButton(button: ButtonId, pressed: bool)    // controller-button mapping mode
    sendKey(keyCode: KeyCode, pressed: bool)      // simulated-keypress mapping mode
    neutralize()                                  // zero all axes, release all buttons/keys
    shutdown()
}

enum AxisType { Steering, Accelerator, Brake, Clutch }
```

### Platform implementations

| Platform | Axis/Button backend | Key simulation |
|---|---|---|
| Windows | ViGEmBus (virtual Xbox controller) | SendInput API |
| Linux | uinput virtual joystick device | uinput synthetic key events |

### Mapping mode

The Input Mapper decides, per dashboard control, whether to call setButton or sendKey. The user's mapping-mode setting drives that decision. Default is simulated key presses, per the PRD.

### neutralize() call sites

neutralize() must be called on:

- WebSocket disconnect
- heartbeat timeout (2 missed beats)
- active device switch
- desktop server shutdown

This guarantees no control can remain stuck on, like a held accelerator, regardless of why the connection ended.

## Known simplification (v1)

Steering and all three pedals are bundled into a single state message rather than sent as independent per-axis messages. This trades granularity for simplicity. Revisit only if testing shows a specific need for independent axis update rates.
