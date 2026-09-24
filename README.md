# WheelDeck

Project Status: **Alpha** — `v0.1.0-alpha.1` prereleased from `main`.

Turn an Android or iOS phone into a steering wheel and dashboard control panel for PC racing and trucking simulators. A desktop companion app translates the phone's input into a virtual game controller the simulator reads natively.

Runs on Linux and Windows desktops paired with an Android or iOS phone; macOS planned.

Primary target: Euro Truck Simulator 2.

## How it works

1. Phone captures gyroscope steering, touch pedals, and dashboard button presses
2. Phone discovers the desktop server on the local network via mDNS
3. One-time PIN pairing establishes a session
4. State and button messages stream over WebSocket in real time
5. Desktop app drives a virtual Xbox controller (Windows/HIDMaestro) or joystick (Linux/uinput)
6. Simulator reads the virtual controller natively — no game plugins needed

## Components

| Directory | Stack | Description |
|-----------|-------|-------------|
| `mobile/` | Flutter (Dart) | Phone app — sensor capture, WebSocket client, on-screen controls (current alpha; Kotlin rewrite in progress, see Migration plan) |
| `desktop/` | C#/.NET 10 + Avalonia UI | Desktop server — WebSocket listener, virtual controller backend, pairing |
| `protocol/schema/` | JSON Schema | Shared message formats and control enums (single source of truth) |

## Release status

- Current: `v0.1.0-alpha.1` (tag on `main`). GitHub Release is a **prerelease** with generated notes.
- Tag push matching `v*` triggers `.github/workflows/release.yml`: Android APK + web bundle, Windows x64 zip, Linux x64 tarball. PWA deploy to GitHub Pages is skipped for `alpha`/`beta` tags — web ships only as a release asset.
- Android alpha is signed with debug keys (`mobile/android/app/build.gradle.kts`); real signing lands before stable.

## Migration plan: mobile Flutter → Kotlin

- Branch: `migrate/flutter-to-kotlin`. Native Android app (Kotlin + Jetpack Compose, Material 3, single `:app` module) in `android/`; built slice by slice while Flutter stays the runnable reference. Plan + checklist live on that branch: `tasks/plan.md`, `tasks/todo.md`, `docs/migration-kotlin.md`.
- Status: Foundation + connection core done, Checkpoint A passed (real-device pairing, reconnect, heartbeat). In progress: driving core (Tasks 7–10), then dashboard completeness (Tasks 11–13), polish + cutover (Tasks 14–15).
- Freeze rule: no new features or fixes in `mobile/` during migration — the seven `TODO.md` Mobile items land as acceptance criteria in the Kotlin build. Cutover deletes `mobile/`, swaps CI from Flutter to Android, and rewrites the mobile docs.

## Project structure

See [`docs/project-structure.md`](docs/project-structure.md) for the full repository layout.

## Quick start

### Phone app

```bash
cd mobile
flutter pub get
flutter run
```

### Desktop server

```bash
cd desktop
dotnet build
dotnet run --project WheelDeck.App
```

Linux: run `scripts/linux/install-uinput-rules.sh` from the repo root, then apply the commands it prints. Covers Fedora/RHEL, Ubuntu/Debian derivatives (Mint, Pop!_OS, Zorin), and Arch-based (CachyOS, Manjaro, EndeavourOS).

See `docs/mobile-dev-guide.md` and `docs/desktop-dev-guide.md` for full setup instructions including platform-specific driver requirements.

## Supported platforms

| Platform | Status | Driver | Virtual controller |
|----------|--------|--------|--------------------|
| Android  | P0 | Native     | Fully functional    |
| iOS      | P2 | PWA        | Gyro may not work   |
| Windows  | P1 | HIDMaestro | XBOX 360 Controller |
| Linux    | P0 | uinput     | Virtual Joystick    |

## Docs

Full specs, guides, and architecture decisions: [`docs/`](docs/)
