# WheelDeck

A mobile app that turns a phone into a steering wheel and dashboard control panel for PC simulators, paired with a desktop server that translates phone input into a virtual game controller.

## Language

**Phone**: The mobile device running the Flutter app that captures steering, pedal, and dashboard input.
_Avoid_: Device, mobile, client

**Desktop**: The machine running the .NET/Avalonia server that receives input and drives the virtual controller.
_Aavoid_: Server, host, PC

**WheelDeckClient**: The mobile end of the WebSocket protocol. Dials the desktop, frames messages, tracks connection status, and handles pairing and heartbeat internally.
_Avoid_: Client (alone), network layer

**Pairing**: The one-time trust establishment where a phone proves it should be allowed to send input to a desktop. Happens via PIN or QR code shown on the desktop and entered/scanned on the phone.
_Avoid_: Pairing, connecting, handshaking

**Session**: An active, authorized connection between a paired phone and the desktop. Established after pairing or when a valid session token is presented.
_Avoid_: Connection, link

**Session token**: Opaque credential issued after successful pairing. Lets a phone skip re-pairing on later sessions until the desktop's 30-day inactivity expiry.
_Avoid_: Token, auth token, credential

**PairedDevice**: A phone that has successfully paired with the desktop. Persists across sessions until revoked or expired.
_Avoid_: Device, trusted device, paired phone

**Active device**: The single paired device currently allowed to reach the input mapper. Only one device is active at a time.
_Avoid_: Current device, selected device, primary device

**Active device switching**: The process of changing which paired device is active. Immediately neutralizes the old device's input before the new device is authorized.
_Avoid_: Switching, handoff, device change

**Neutralize**: Zero all axes and release all buttons and keys on the virtual controller. Triggered on WebSocket disconnect, heartbeat timeout, active-device switch, and server shutdown.
_Avoid_: Reset, clear, zero, center

**Steering**: Phone rotation captured via gyroscope, normalized to -1.0..1.0 where 0 is straight ahead.
_Avoid_: Wheel, rotation, yaw

**Calibration**: Capturing the phone's current orientation as "straight ahead" (the center point for steering).
_Avoid_: Centering, zeroing, reset

**Pedal**: Accelerator, brake, or clutch. Touch-drag position maps to analog pressure 0.0..1.0 with spring-back release.
_Avoid_: Throttle, input, axis

**Control**: A discrete dashboard button (parking brake, turn signals, lights, wipers, cruise control, engine start).
_Avoid_: Button, switch, toggle

**Action**: The kind of interaction with a control: toggle, press, release, or hold_confirm.
_Aavoid_: Event, input, click

**VirtualOutputBackend**: OS-specific abstraction for driving a virtual controller. Windows uses ViGEmBus; Linux uses uinput.
_Avoid_: Backend, driver, output

**InputMapper**: Routes incoming axes and buttons to the virtual controller per mapping mode (virtual-controller buttons or simulated key presses).
_Aavoid_: Mapper, router, translator

**PairingManager**: Manages pairing and session state. Enforces 30-day inactivity expiry and the active/non-expired/non-revoked gate before input reaches the mapper.
_Avoid_: Pairing service, device manager

**State message**: Continuous steering and pedal state sent on every sensor or touch update. Latest value wins; no acknowledgment required.
_Aavoid_: Sensor message, axis message, input frame

**Button message**: Discrete dashboard control event. Delivered reliably over TCP.
_Aavoid_: Control message, event frame

**Heartbeat**: Standalone keep-alive message sent every ~2s. Does not carry or resend state. Two missed beats triggers neutralize on the desktop.
_Aavoid_: Keep-alive, ping, alive

**Auto-reconnect**: On unexpected connection drops (Wi-Fi fade, PWA suspend), the client automatically retries the last target. Manual disconnect clears the target and stops retries.
_Avoid_: Reconnect, retry, recovery

**PWA reconnect**: When the iOS PWA returns from background, it fires a reconnect to the last-known IP and mDNS discovery in parallel. Whichever succeeds first wins.
_Avoid_: Foreground reconnect, PWA recovery

**Calibration reconfirm**: On resume from background/call/lock, the app prompts the user to confirm the gyro center hasn't drifted. Always prompts regardless of detected drift.
_Avoid_: Recalibration, drift check

**Setup check**: First-run check for ViGEmBus (Windows) or uinput permissions (Linux). Degraded-continue on failure — show instructions but don't block pairing.
_Avoid_: First-run check, driver check, prerequisite check

**Setup scripts**: Platform-specific first-run helpers. Windows (`check-vigembus.ps1`) detects ViGEmBus and offers to launch the browser to the official release page. Linux (`install-uinput-rules.sh`) detects uinput/SELinux issues and prints remediation commands for the user to run manually.
_Avoid_: Install scripts, setup helpers, first-run scripts

**Onboarding flow**: Linear multi-step first-run flow: permissions → discovery/pairing → calibration confirm → driving screens. Each step validates before advancing.
_Avoid_: Onboarding wizard, setup wizard, first-run flow
