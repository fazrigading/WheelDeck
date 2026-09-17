# WheelDeck

A mobile app that turns a phone into a steering wheel and dashboard control panel for PC simulators, paired with a desktop server that translates phone input into a virtual game controller.

## Language

**Phone**: The mobile device running the Flutter app that captures steering, pedal, and dashboard input.
_Avoid_: Device, mobile, client

**Desktop**: The machine running the .NET/Avalonia server that receives input and drives the virtual controller.
_Avoid_: Server, host, PC

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

**Steering**: Normalized -1.0..1.0 where 0 is straight ahead, regardless of input mode.
_Avoid_: Wheel, rotation, yaw

**Gyro steering**: Phone rotation captured via gyroscope; tilt maps to steering.
_Avoid_: Tilt steering, motion steering

**Rotatable steering**: Finger-drag circular wheel on the phone; N degrees of finger rotation equals full lock-to-lock.
_Avoid_: Rotateable, drag wheel, circular steering

**Rotation degree**: The finger-rotation range mapping to full lock-to-lock. Selectable 180, 270, 900, 1080, 1800, or 2520; 900 is the ETS2 default. Gyro steering is unaffected.
_Avoid_: Sensitivity, range, lock

**Rotation indicator**: Rotating wheel graphic plus an arc above the ring showing rotation.
_Avoid_: Angle readout, progress ring

**Rotatable grid**: The rotatable-mode dashboard surface: six blocks in 2 rows x 3 columns tiling the landscape screen.
_Avoid_: Block grid, cell grid, dashboard grid

**Block**: One of the six 4-row x 5-column regions of the rotatable grid, addressed as block[row, col].
_Avoid_: Region, panel, zone

**Cell**: The 1x1 unit of the rotatable grid: screen width over 15 by screen height over 8. Aspect follows the screen.
_Avoid_: Tile, square

**Slot**: A rectangular run of cells in a block holding one dashboard item: a control, pedal, gear button, the wheel, or the camera pad.
_Avoid_: Placement, area

**Hole**: A slot with no control assigned yet; renders disabled.
_Avoid_: Empty slot, placeholder

**Layout preset**: The named, authoritative arrangement of slots for the rotatable screen; user binding overrides beat preset defaults.
_Avoid_: Profile, theme, skin

**Sequential**: The first layout preset: gear-up/gear-down sequential shifting, camera pad in the top-right block, wheel bottom-left, pedals bottom-right.
_Avoid_: Default layout

**Camera pad**: The 3x3 directional pad driving in-game camera look, with a Numpad mode and an Arrow mode and a center cell that recenters or switches mode.
_Avoid_: D-pad, camera control

**Numpad mode**: Camera pad mode sending numpad keys for directions.
_Avoid_: Keypad mode

**Arrow mode**: Camera pad mode sending arrow keys; diagonals disabled and no recenter key.
_Avoid_: Arrow-key mode

**Tap-or-hold**: Cell interaction where a short tap performs the tap action and holding past the threshold performs the hold action instead; never both.
_Avoid_: Long press, press-and-hold

**Controller visibility**: Independent show/hide for Clutch and Dashboard; Steering Wheel, Accelerator, and Brake always shown.
_Avoid_: Controller type, toggles

**Pedal side**: Per-pedal Left or Right screen placement for each shown pedal.
_Avoid_: Pedal layout, pedal position

**Light cycle**: Headlight control cycling OFF → Parking Lights → Low Beam, with state held on the phone. High-beam stays independent.
_Avoid_: Light modes, light toggle

**Engine start mode**: Engine Start engages by hold-confirm or single press, per user setting.
_Avoid_: Hold to start, press to start

**Tilt readout**: Horizontal X-axis line under the gyro wheel shifting with tilt angle.
_Avoid_: X-axis line, tilt line

**Turn signal**: Left or Right blinking indicator; the two are mutually exclusive — turning one on while the other is on cancels the other, in the app and in game. Independent of hazard.
_Avoid_: Blinker, indicator

**Hazard**: Both turn signals blinking together at ~1.5Hz, independent of the individual Left/Right signals. A signal turned on while hazard is active keeps its own blink and does not cancel hazard; in-game light output shows hazard while both are active.
_Avoid_: Hazard lights, emergency blink

**Unbound control**: A control whose per-mode keybind is empty. The phone sends nothing; the desktop ignores unknown controls as safety net.
_Avoid_: Empty keybind, unmapped control

**Calibration**: Capturing the phone's current orientation as "straight ahead" (the center point for steering).
_Avoid_: Centering, zeroing, reset

**Pedal**: Accelerator, brake, or clutch. Touch-drag position maps to analog pressure 0.0..1.0 with spring-back release.
_Avoid_: Throttle, input, axis

**Control**: A discrete dashboard button (parking brake, turn signals, lights, wipers, cruise control, engine start).
_Avoid_: Button, switch, toggle

**Action**: The kind of interaction with a control: toggle, press, release, or hold_confirm.
_Avoid_: Event, input, click

**VirtualOutputBackend**: OS-specific abstraction for driving a virtual controller. Windows uses HIDMaestro; Linux uses uinput.
_Avoid_: Backend, driver, output

**InputMapper**: Routes incoming axes and buttons to the virtual controller per mapping mode (virtual-controller buttons or simulated key presses).
_Avoid_: Mapper, router, translator

**Mapping mode**: How dashboard controls reach the truck: keyboard mode simulates key presses; gamepad mode presses virtual-controller buttons, using keyboard keys only for controls without a gamepad binding.
_Avoid_: Input mode, control scheme

**PairingManager**: Manages pairing and session state. Enforces 30-day inactivity expiry and the active/non-expired/non-revoked gate before input reaches the mapper.
_Avoid_: Pairing service, device manager

**State message**: Continuous steering and pedal state sent on every sensor or touch update. Latest value wins; no acknowledgment required.
_Avoid_: Sensor message, axis message, input frame

**Button message**: Discrete dashboard control event. Delivered reliably over TCP.
_Avoid_: Control message, event frame

**Heartbeat**: Standalone keep-alive message sent every ~2s. Does not carry or resend state. Two missed beats triggers neutralize on the desktop.
_Avoid_: Keep-alive, ping, alive

**Auto-reconnect**: On unexpected connection drops (Wi-Fi fade, PWA suspend), the client automatically retries the last target. Manual disconnect clears the target and stops retries.
_Avoid_: Reconnect, retry, recovery

**PWA reconnect**: When the iOS PWA returns from background, it fires a reconnect to the last-known IP and mDNS discovery in parallel. Whichever succeeds first wins.
_Avoid_: Foreground reconnect, PWA recovery

**Calibration reconfirm**: On resume from background/call/lock, the app prompts the user to confirm the gyro center hasn't drifted. Always prompts regardless of detected drift.
_Avoid_: Recalibration, drift check

**Setup check**: First-run check for HIDMaestro (Windows) or uinput permissions (Linux). Degraded-continue on failure — show instructions but don't block pairing.
_Avoid_: First-run check, driver check, prerequisite check

**Setup scripts**: Platform-specific first-run helpers. Windows (`check-hidmaestro.ps1`) reports HIDMaestro driver status; the app installs the driver automatically (admin required). Linux (`install-uinput-rules.sh`) detects uinput/SELinux issues and prints remediation commands for the user to run manually.
_Avoid_: Install scripts, setup helpers, first-run scripts

**Onboarding flow**: Linear multi-step first-run flow: permissions → discovery/pairing → calibration confirm → driving screens. Each step validates before advancing.
_Avoid_: Onboarding wizard, setup wizard, first-run flow
