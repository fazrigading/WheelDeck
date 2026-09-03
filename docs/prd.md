# WheelDeck product requirements document (draft v0.5)

## Overview

A mobile app that turns a phone into a steering wheel and dashboard control panel for PC racing and trucking simulators. A desktop companion app translates the phone's input into a virtual game controller the simulator reads natively. Primary target: Euro Truck Simulator 2.

## Target user

Someone who owns a PC simulator game and does not have a physical wheel and pedal setup, but has a spare or primary phone and wants a low-cost, no-extra-hardware way to get analog steering instead of keyboard-only controls. This includes people who play in public or shared spaces, not just at home.

## Goals

- Let a phone's gyroscope control in-game steering by physically rotating the device.
- Provide analog accelerator, brake, and clutch controls alongside the wheel.
- Provide a dashboard panel of discrete truck controls (parking brake, turn signals, lights, wipers, cruise control, engine start) styled after real truck buttons.
- Support Windows and Linux (Fedora primary target) desktop platforms from a single codebase.
- Support Android natively and iOS via a progressive web app (PWA), so the same phone-control experience reaches iOS without an Apple Developer subscription.
- Keep input latency low enough to feel usable for real-time driving, not turn-based.
- Support secure pairing so use in public or shared spaces does not expose the desktop to untrusted input.

## Non-goals (v1)

- Simulators other than ETS2. The architecture should allow it later, but v1 targets ETS2 only for testing and tuning.
- Multiple saved control profiles or per-game remapping UI.
- Online or remote play. This is local-network or USB-tethered only, not internet-routed.

## Future plans (post-v1)

- macOS desktop support.
- Bluetooth transport. Deferred due to iOS platform restrictions. Classic Bluetooth SPP requires MFi certification, so iOS would be limited to BLE, which splits the implementation from Android's simpler classic-Bluetooth path. BLE also has weaker throughput and latency than Wi-Fi for continuous wheel data.
- Force feedback / rumble.
- Additional simulator profiles beyond ETS2.
- Custom control layout editor.

## Technical stack

Desktop app: C#/.NET with Avalonia UI, a cross-platform XAML UI framework. Chosen over WPF because WPF is Windows-only and would force a split UI codebase between Windows and Linux. Linux is now equal priority to Windows, not a stretch platform, so one Avalonia codebase covers both from a single project.

Desktop output backends: platform-specific implementations behind a shared interface. ViGEmBus on Windows, uinput on Linux. See backend-interface.md.

Mobile app: Flutter, shipped as a native Android app and as a progressive web app for iOS. The PWA path avoids the Apple Developer Program fee while keeping the same Flutter UI and WebSocket client. See mobile-interface.md.

## Target platforms & scope (v1)

| Component | Platform | Priority |
|---|---|---|
| Mobile app | Android (native) | P0 |
| Mobile app | iOS (PWA) | P0 |
| Desktop server | Linux (Fedora) | P0 |
| Desktop server | Windows | P0 |

## Transport

Primary: local Wi-Fi, phone and desktop on the same network.

Fallback: USB tethering, for cases where Wi-Fi is unreliable or blocked (public or guest networks with client isolation).

Discovery: auto-discovery (mDNS-style broadcast) as the default connection method, with manual IP entry as a fallback when broadcast is blocked.

## Feature list

### Mobile app

1. Steering wheel view. On-screen wheel graphic, phone rotation (gyroscope) maps to wheel angle in-game. Sensitivity and max-rotation-angle are user-adjustable in-app settings, not fixed.
2. Pedals. Accelerator, brake, and clutch shown as vertical draggable bars. Dragging down sets analog pressure based on touch position. Releasing lets the bar spring back toward the top at a tunable rate, mimicking real pedal return.
3. Dashboard panel. Toggleable and pressable controls: parking brake, turn signal left (simple toggle), turn signal right (simple toggle), headlight toggle, high-beam toggle, wipers, cruise control on/off, cruise control set/resume, engine start/stop.
4. Connection screen. Auto-discovers nearby paired desktop servers, falls back to manual IP entry, and shows connection status.
5. Pairing. First connection to a new desktop server requires a pairing step (PIN or QR code shown on desktop, entered or scanned on phone). Pairing persists between sessions, so future connections from the same phone skip re-pairing.
6. Calibration. The user sets the phone's "center" (straight-ahead) orientation before driving.
7. Onboarding / permission prompts. Request motion sensor and local network access with a clear explanation of why each is needed.

### Desktop server

1. Virtual controller output. Windows via ViGEmBus, Linux via uinput.
2. Network listener. Receives wheel, pedal, and button data from the mobile app over Wi-Fi or USB tethering.
3. Pairing management. Generates a PIN or QR for new phones, maintains a list of previously paired phones, lets the user choose which paired phone is currently active and connected, and revoke devices manually.
4. Connection management UI. Shows connection status, active paired device, and basic troubleshooting info (firewall reminder, etc.).
5. Input mapping. Translates incoming wheel angle to controller axis, pedal pressure to analog axes, and dashboard buttons to either virtual-controller buttons or simulated key presses. User-selectable, default is simulated key presses to match ETS2's default keybinds.
6. First-run setup check. Verify ViGEmBus is installed (Windows) or uinput permissions are configured (Linux), and tell the user what is missing rather than failing silently.
7. Launch mode. Manual launch is the default; the user opens the app when they want to play. Running as a background service or daemon that starts automatically is an opt-in advanced setting, kept out of the main flow so it does not add friction for typical users.

## Functional requirements (detail)

- Wheel rotation must map to a continuous axis value, not discrete steps, for smooth steering.
- Pedal release (spring-back) rate should feel natural, not an instant snap to zero. This needs an actual decay curve, worth prototyping the feel early since it is a core interaction.
- Engine start should require a deliberate action (press-and-hold or a two-step confirm) to avoid accidental triggers during normal driving.
- Connection loss should be handled gracefully. If the phone disconnects mid-drive, the desktop server should release or neutralize the virtual controller rather than leaving the last input state stuck (a stuck-on accelerator).
- App lifecycle edge cases. Phone call, screen lock, or backgrounding mid-drive should neutralize or pause input rather than send stale or frozen values.
- Screen orientation. The app should lock to one orientation during driving so the gyroscope mapping stays predictable.
- Reconnection. Brief Wi-Fi drops should trigger auto-reconnect with a visible status indicator, not require manual reconnection.
- Multi-device handling. Desktop only accepts input from the currently active paired phone. Switching the active device should cleanly hand off (old device's input ignored, new device's input taken over) without a stuck-input gap.

## Non-functional requirements

Latency: sub-50ms round trip is a reasonable initial target to validate once a prototype exists.

Security: pairing (PIN/QR) required before any input is accepted, given the public-space use case. Paired devices auto-expire after roughly one month of inactivity and can be manually revoked from the desktop's paired-device list, so persistent pairing does not turn into indefinite stale trust.

Battery usage: continuous gyroscope polling and network transmission will drain the phone faster than idle use. Advise users to keep the phone plugged in during long sessions.

Installation friction: Windows requires installing ViGEmBus once. Linux requires uinput permission setup. Both should be handled by a setup script or clearly documented first-run steps.

## Technical constraints / assumptions

- iOS PWA execution is suspended when Safari backgrounds or the screen locks, so the WebSocket may drop on iOS even when Android keeps the connection. The app must treat this as a normal disconnect and auto-reconnect on foreground, matching the existing lifecycle rules.
- Fedora's default SELinux enforcement may require testing and adjusting uinput permission setup beyond a generic Linux udev rule.
- USB tethering fallback requires OS-level driver support for tethered networking on both Windows and Linux. Generally standard, but worth explicit testing on Fedora.
- Avalonia UI requires .NET runtime availability on the target Linux distribution. Worth confirming the packaging approach (self-contained deployment vs. requiring the user to have .NET installed) during setup.

## Risks

- Touch-based analog pedals may not feel as controllable as a real pedal. Worth prototyping early rather than assuming it will feel fine.
- Gyroscope drift and calibration accuracy vary by phone hardware. Behavior may be inconsistent across devices without per-device tuning.
- A background or daemon launch mode slightly increases attack surface, since the server runs even when the user is not actively playing. Worth a design note that daemon mode should still require an active paired-and-connected phone before accepting any input, same as manual launch.

## Success criteria (v1)

- A user can install the mobile app and desktop server, pair once, and reconnect automatically on future sessions.
- A user can drive a truck in ETS2 using phone rotation for steering and analog pedals for throttle, brake, and clutch, with all dashboard controls functioning correctly in-game.
- Works on both Windows and Fedora Linux without platform-specific bugs blocking basic driving.
- Falls back cleanly to USB tethering when Wi-Fi is unavailable or blocked.
