# WheelDeck mobile app interface specification

## Overview

This document specifies the internal interfaces on the mobile app side: how sensor and touch input is captured and normalized, how the networking layer talks to the desktop server, and what the networking layer exposes to the UI layer. It mirrors backend-interface.md. The wire protocol here is the same one the desktop consumes.

## Architecture

```
UI Layer (Wheel view, Pedal bars, Dashboard panel, Connection/Pairing screens)
   ^
   |  (state updates, connection status, calibration events)
   v
Input Capture Layer   -> gyroscope sampling, touch-to-pressure mapping, calibration
   v
Network Client Layer  -> WebSocket connection, message framing, pairing, heartbeat
   v
Transport (Wi-Fi / USB tethering)
```

## 1. Input capture layer

### 1.1 Steering (gyroscope)

```
interface SteeringSensor {
    start(): void
    stop(): void
    setCenter(): void                       // calibration: captures current
                                            // orientation as "straight ahead"
    setSensitivity(value: float): void      // maps physical rotation range to
                                            // full-lock; user-adjustable, per PRD
    onAngleChanged(callback: (angle: float) => void): void
                                            // angle normalized -1.0..1.0,
                                            // already centered and scaled
}
```

Raw gyroscope/orientation data is normalized here, not in the UI layer or the network layer. The wheel widget and the network client both consume an already-calibrated -1.0..1.0 value.

### 1.2 Pedals (touch-position pressure)

```
interface PedalInput {
    onPressureChanged(callback: (pedal: PedalType, pressure: float) => void): void
    setReleaseCurve(curve: ReleaseCurve): void   // spring-back rate, per PRD
}

enum PedalType { Accelerator, Brake, Clutch }
```

Each pedal bar owns its own drag-position-to-pressure mapping (0.0 at rest, 1.0 at full drag) and its own release animation. setReleaseCurve makes this tunable later without changing the interface. Start with one default curve and expose tuning only if testing shows it is needed.

### 1.3 Dashboard controls

```
interface DashboardInput {
    onControlActivated(callback: (control: ControlId, action: ActionType) => void): void
}

enum ControlId {
    ParkingBrake, TurnSignalLeft, TurnSignalRight, HeadlightToggle,
    HighBeamToggle, Wipers, CruiseToggle, CruiseSetResume, EngineStart
}

enum ActionType { Toggle, Press, Release, HoldConfirm }
```

Same enum values as the backend spec's control list and action types. This symmetry matters because it is what keeps the two docs in sync as the project evolves.

## 2. Network client layer

```
interface WheelDeckClient {
    connect(target: ConnectionTarget): ConnectionResult
    disconnect(): void
    sendState(steering: float, accelerator: float, brake: float, clutch: float): void
    sendButtonEvent(control: ControlId, action: ActionType): void
    onConnectionStatusChanged(callback: (status: ConnectionStatus) => void): void
    onPairingRequired(callback: (pairing: PairingChallenge) => void): void
    submitPairingCode(code: string): void
}

enum ConnectionStatus { Disconnected, Discovering, Connecting, PairingRequired, Connected, Reconnecting }

struct ConnectionTarget {
    mode: "auto_discover" | "manual"
    ipAddress?: string     // only used when mode = manual
    port?: int
}

struct PairingChallenge {
    method: "pin" | "qr_scan"
}
```

### 2.1 Discovery

- auto_discover mode listens for the desktop server's broadcast (mDNS-style) and surfaces found servers to the UI for selection.
- manual mode is the fallback for networks that block broadcast (public Wi-Fi with client isolation, per PRD). The user enters IP/port directly.

### 2.2 Pairing flow

1. Client connects. The desktop responds with pair_response: required if this device is not already paired or its pairing expired.
2. UI shows PairingChallenge (PIN entry field or QR scanner).
3. submitPairingCode() sends pair_request with the entered or scanned value.
4. On success, the desktop marks the device paired. The client stores the session token locally so future connections skip pairing. This persists across sessions per the PRD until the desktop's roughly 30-day inactivity expiry.

### 2.3 Message send rate

sendState() is called on every sensor/touch update tick, not batched or debounced. The desktop's seq field handles ordering, and the PRD's latency target assumes near-real-time sends rather than periodic batching.

### 2.4 Heartbeat

Handled internally by WheelDeckClient, not exposed to the UI layer beyond ConnectionStatus. The client sends and expects heartbeats every ~2s and transitions to Reconnecting automatically on missed beats, matching the desktop's neutralize-on-timeout behavior.

## 3. App lifecycle handling

The network client must respond to OS-level lifecycle events without the UI layer managing this explicitly.

| Event | Behavior |
|---|---|
| Incoming call | Pause input send, hold last-known state locally, do not transmit until resumed |
| Screen lock | Disconnect gracefully (send explicit "input paused" signal if possible, else let heartbeat timeout trigger desktop-side neutralize) |
| App backgrounded | Same as screen lock |
| App foregrounded / call ended | Require calibration re-confirm before resuming input, since phone orientation may have changed while paused |

This satisfies the PRD's requirement that lifecycle interruptions neutralize input rather than send stale or frozen values, without pushing that logic into every screen that touches the wheel or pedals.

## 4. Orientation lock

The UI layer should lock device orientation during an active driving session (wheel view, pedal view, dashboard view) so the SteeringSensor calibration stays valid. Device rotation for steering must not be conflated with UI orientation changes.

## Known simplification (v1)

Reconnection after a dropped Wi-Fi connection uses a fixed retry interval rather than exponential backoff. That is fine for a LAN-only v1 use case. Revisit only if real-world testing shows reconnect storms are an issue, which is unlikely at this scale.
