# Kotlin Migration Guide

How the mobile app migrates from Flutter (Dart) to Android-native Kotlin + Jetpack Compose. The approved plan and per-task acceptance criteria live in [`../tasks/plan.md`](../tasks/plan.md); the running checklist is [`../tasks/todo.md`](../tasks/todo.md).

## Strategy

**Parallel until parity.** The Kotlin app is built slice by slice in `android/` while Flutter stays runnable as the working reference. At every checkpoint, Flutter must still build and pass `flutter test`. Only the final cutover task deletes `mobile/`.

- **Target:** Android-native, Jetpack Compose, Material 3, single `:app` module, no DI framework (manual `AppContainer`). iOS remains P2/PWA — nothing changes there.
- **Local data:** fresh start. No SharedPreferences/DataStore migration; pairing costs one PIN scan.
- **Freeze rule:** `mobile/` gets no new features and no bug fixes during migration. The seven `TODO.md` Mobile items are built right the first time in Kotlin as acceptance criteria — no bug-for-bug parity, no double work.

## Dependency map

| Flutter | Kotlin | Notes |
|---|---|---|
| `sensors_plus` | `SensorManager` | TYPE_GYROSCOPE / TYPE_GAME_ROTATION_VECTOR; same device coordinate frame, math ports cleanly |
| `multicast_dns` | `NsdManager` | Android wants `_wheeldeck._tcp.` (trailing dot); Dart used `_wheeldeck._tcp.local` |
| `web_socket_channel` | OkHttp WebSocket | Test with MockWebServer |
| `shared_preferences` | DataStore Preferences | Fresh start, no migration |
| `permission_handler` | Runtime permission APIs | Behind a `PermissionService` seam |
| `provider` | ViewModel + StateFlow | ChangeNotifier → StateFlow |
| `freezed` | `data class` | No codegen needed |
| `http` / `url_launcher` | OkHttp / `Intent.ACTION_VIEW` | |
| Dart `Stream` / `Future` | `Flow` / coroutines | |

## Layer mapping

The Dart layering ports 1:1:

| Dart (`mobile/lib/`) | Kotlin (`android/app/src/main/kotlin/dev/fazrigading/wheeldeck/`) |
|---|---|
| `domain/models/*.dart` (+ freezed) | `domain/models/*.kt` (data classes) |
| `data/services/*.dart` | `data/services/*.kt` |
| `data/repositories/*.dart` | `data/repositories/*.kt` |
| `ui/features/*/views/*.dart` | `ui/features/*/views/*.kt` (Compose) |
| `ui/features/*/view_models/*.dart` | `ui/features/*/view_models/*.kt` (ViewModel + StateFlow) |
| `ui/core/**` | `ui/core/**` |
| `ui/core/theme/app_theme.dart` | Compose Material 3 theme |

## Porting rules

1. **Protocol is the contract.** `protocol/schema/*.json` stays the single source of truth. Kotlin message models must stay wire-compatible with the desktop; the ported `control_contract_test` and `input_mapping_test` pin this.
2. **Port tests with the source.** Each task's Dart tests port 1:1 (JUnit + `kotlinx-coroutines-test`, MockWebServer for the client, Robolectric/fakes where Android framework APIs need seams). Ported tests passing is the parity gate. Compose UI tests only where gestures require them.
3. **Hide platform APIs behind interfaces** where logic needs testing: `NsdManager`, `SensorManager`, permissions. Logic stays fake-testable; the thin adapter is verified on real hardware.
4. **Known fixes, not bugs.** The seven `TODO.md` items land as acceptance criteria in Tasks 10–13 (constant-speed wheel return; gear 2×1; ACC+BRK 4×3 group; inter-block padding; camera pad `auto` keybinds; keyboard-afloat modal; Keybind Configuration page).
5. **ADRs carry over.** ADR-0002 (fixed reconnect interval), ADR-0003 (standalone heartbeat), ADR-0006 (camera pad wire identifiers) apply unchanged to the Kotlin client.

## App conventions

- Package: `dev.fazrigading.wheeldeck` (same applicationId as the Flutter app).
- minSdk 26, targetSdk 36; version catalog in `gradle/libs.versions.toml`.
- Domain terms follow [`CONTEXT.md`](../CONTEXT.md) exactly (Phone, Desktop, WheelDeckClient, Pairing, Session, Slot, Hole, ...).

## Checkpoints

| Checkpoint | Gate |
|---|---|
| Foundation | Builds + tests in CI; wire contract pinned |
| A (after connection slice) | Real-device pairing, reconnect, heartbeat; Flutter still green |
| B (after driving core) | Real-device ETS2 session: gyro/rotatable steering, pedals, camera pad |
| C (after dashboard) | Side-by-side parity + the seven fixes; both test suites green |

## Cutover checklist (final task)

- [ ] Checkpoint C passed on real hardware
- [ ] `docs/mobile-dev-guide.md` rewritten for Kotlin
- [ ] `README.md` + `docs/project-structure.md` updated
- [ ] CI: Android build+test job in, Flutter job out
- [ ] `mobile/` deleted
- [ ] Plan archived to `plan/finished/migration-kotlin-1.md`
- [ ] Mobile TODO items checked off in `TODO.md`
