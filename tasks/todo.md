# Task List: Flutter → Kotlin Migration

Plan details, acceptance criteria, and verification commands: [`tasks/plan.md`](plan.md).

## Phase 1: Foundation

- [x] Task 1: Scaffold Android project (`android/`, Gradle KTS, Compose M3, theme port, CI job)
- [x] Task 2: Protocol models + contract tests (kotlinx.serialization vs `protocol/schema/`)

## Checkpoint: Foundation

- [ ] Android builds + tests run in CI; wire contract pinned

## Phase 2: Connection core

- [x] Task 3: mDNS discovery (NsdManager, `_wheeldeck._tcp.`, manual-IP fallback)
- [x] Task 4: WebSocket client (OkHttp, framing, heartbeat, auto-reconnect)
- [x] Task 5: Pairing + session (PIN, token reuse, DataStore persistence)
- [ ] Task 6: Connection UI (screen, manual-add sheet, coordinator, lifecycle)

## Checkpoint A: Connection works end-to-end

- [ ] Pairs with real desktop, reconnects after Wi-Fi fade, heartbeats hold; `flutter test` still green

## Phase 3: Input capture + driving core

- [ ] Task 7: Gyro steering (SensorManager, calibration + reconfirm, rotation mapper)
- [ ] Task 8: Pedal input (touch-drag analog, spring-back)
- [ ] Task 9: Driving VM + send gate + visibility + wheel mode
- [ ] Task 10: Driving screen (RotatableWheel, tilt readout, pedals, camera pad; **constant-speed rotate-back-to-zero**)

## Checkpoint B: Drivable

- [ ] Real-device ETS2 session: gyro + rotatable steering, pedals, camera pad; `flutter test` still green

## Phase 4: Dashboard completeness

- [ ] Task 11: Rotatable grid layout engine (**gear 2×1, ACC+BRK group 4×3, inter-block padding**)
- [ ] Task 12: Dashboard controls (signals/hazard/lights/engine; **camera pad keybinds default `auto`**)
- [ ] Task 13: Onboarding + permissions + settings (**Keybind Configuration page; keyboard afloat, dashboard doesn't resize**)

## Checkpoint C: Parity + fixes

- [ ] Side-by-side parity vs Flutter + all seven TODO.md fixes verified; `./gradlew test` and `flutter test` green

## Phase 5: Polish + cutover

- [ ] Task 14: Menu / about / donate screens
- [ ] Task 15: Cutover (docs rewrite, CI update, delete `mobile/`, archive plan, check off TODO.md items)

## Checkpoint: Complete

- [ ] All acceptance criteria met; ready for review
