---
goal: Migrate the Windows virtual controller backend from ViGEmBus (retired, kernel-mode) to HIDMaestro (active, user-mode UMDF2)
version: '1.1'
date_created: '2026-09-05'
last_updated: '2026-09-11'
owner: 'fazrigading'
status: 'Ongoing'
tags:
  - migration
  - infrastructure
  - upgrade
---

# Introduction

![Status: Ongoing](https://img.shields.io/badge/status-Ongoing-purple)

Migrate the Windows virtual controller backend from ViGEmBus to HIDMaestro. ViGEmBus is retired and requires a kernel driver plus an EV code-signing certificate for new builds. HIDMaestro is a user-mode UMDF2 driver with a managed C# SDK (vendored `HIDMaestro.Core.dll`, 228+ embedded device profiles, no kernel dependency). The `VirtualOutputBackend` interface in `WheelDeck.Core` decouples business logic from the driver, making this a targeted swap of the Windows backend implementation. As of 2026-09-11 the desktop tree is still 100% ViGEmBus (no HIDMaestro code, no SDK reference); all 5 phases are unstarted.

## 1. Requirements & Constraints

- **REQ-001**: The Windows backend must produce a virtual Xbox 360 controller recognizable by XInput and DirectInput.
- **REQ-002**: All existing `VirtualOutputBackend` methods must continue to work identically: `Initialize()`, `SetAxis()`, `SetButton()`, `SendKey()`, `Neutralize()`, `Shutdown()`.
- **REQ-003**: The virtual controller must present VID `0x045E` and PID `0x028E` (Xbox 360 Controller for Windows) to match current behavior.
- **REQ-004**: No changes to `WheelDeck.Core` or `WheelDeck.Backends.Linux` are permitted.
- **REQ-005**: Keyboard simulation via `SendInputKeySimulator` must remain unchanged.
- **REQ-006**: The HIDMaestro SDK must be vendored as `HIDMaestro.Core.dll` under `desktop/third_party/HIDMaestro/` (there is no NuGet feed as of 2026-09-11).
- **SEC-001**: The new backend must not introduce any network listeners or open ports.
- **SEC-002**: The HIDMaestro driver runs in user mode (UMDF2); no kernel-mode code is introduced. Exception: composite USB personas optionally deploy the bundled signed usbip-win2 transport on demand; WheelDeck uses only the standard `xbox-360-wired` profile and never triggers this path.
- **CON-001**: HIDMaestro SDK targets `net10.0-windows10.0.26100.0`, x64 only. Consuming projects must retarget from `net10.0` to `net10.0-windows10.0.26100.0` with `<Platforms>x64</Platforms>`. x86 / AnyCPU are not supported.
- **CON-002**: HIDMaestro requires administrator privileges (`SeLoadDriverPrivilege`) for `InstallDriver()` and `CreateController()`. `InstallDriver()` throws `UnauthorizedAccessException` when not elevated and `InvalidOperationException` when signing/`pnputil` fails. The setup check must handle both.
- **CON-003**: The migration must not break the Linux uinput backend or the `CompositionRoot` OS-conditional factory.
- **GUD-001**: Follow the official HIDMaestro integration sequence verbatim: `new HMContext()` → `LoadDefaultProfiles()` → `InstallDriver()` → `CreateController(ctx.GetProfile("xbox-360-wired")!)` → `ctrl.SubmitState(HMGamepadState)` (see hidmaestro.org/docs/start/installation and /docs/start/quickstart).
- **GUD-002**: All new code must pass `dotnet build` with zero warnings and `dotnet test` with all tests passing.
- **PAT-001**: Backends are split per platform (`Windows/`, `Linux/`) behind the `VirtualOutputBackend` interface. The Core project never references a specific backend. This pattern is preserved.

## 2. Implementation Steps

### Implementation Phase 1: Vendor HIDMaestro SDK and retarget frameworks

- GOAL-001: Vendor `HIDMaestro.Core.dll` into the repo and retarget the Windows projects to the SDK's required TFM so the new backend can reference its managed API.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-001 | Vendor the SDK: download the latest HIDMaestro release ZIP (or `scripts/build_all.cmd` from source per hidmaestro.org/docs/start/installation) and copy `HIDMaestro.Core.dll` to `desktop/third_party/HIDMaestro/HIDMaestro.Core.dll`. Record the release version and file SHA256 in `desktop/third_party/HIDMaestro/README.md` (create the file). Do NOT use NuGet: upstream states "Until a NuGet feed is published, reference it from a release ZIP or build it from source." | | |
| TASK-002 | In `desktop/WheelDeck.Backends/Windows/WheelDeck.Backends.Windows.csproj`: change `<TargetFramework>net10.0</TargetFramework>` to `<TargetFramework>net10.0-windows10.0.26100.0</TargetFramework>`, add `<Platforms>x64</Platforms>`, and add `<Reference Include="HIDMaestro.Core"><HintPath>..\..\third_party\HIDMaestro\HIDMaestro.Core.dll</HintPath></Reference>`. | | |
| TASK-003 | In `desktop/WheelDeck.App/WheelDeck.App.csproj`: apply the same TFM retarget (`net10.0-windows10.0.26100.0` + `<Platforms>x64</Platforms>`) and the same `<Reference>` to the vendored DLL (the composition root and setup checker call `HMContext`). Run `dotnet restore` and `dotnet build` from `desktop/` to verify the DLL resolves and the solution compiles. Fix any framework compatibility issues. | | |

### Implementation Phase 2: Create the new HIDMaestro backend

- GOAL-002: Replace `ViGEmXboxBackend` with `HidMaestroBackend` implementing the same `VirtualOutputBackend` interface using the HIDMaestro managed SDK.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-004 | Create `desktop/WheelDeck.Backends/Windows/HidMaestroBackend.cs`. Implement `VirtualOutputBackend`. In `Initialize()` (under `_lock`): call `HMOemNameOverride.RecoverOrphans()` (safe on every startup, restores joy.cpl labels after crashes); create `HMContext`; call `ctx.LoadDefaultProfiles()`; call `ctx.InstallDriver()` inside try/catch (`UnauthorizedAccessException` → `BackendResult.Failure("HIDMaestro driver install requires administrator privileges. Run as administrator and retry.")`; `InvalidOperationException` → `BackendResult.Failure` with the exception message); then `var profile = ctx.GetProfile("xbox-360-wired") ?? Failure("xbox-360-wired profile not found")`; then `ctx.CreateController(profile)` and hold the returned `HMController` in a field. On any failure dispose `HMContext` and return `BackendResult.Failure(...)` with a descriptive error. `InstallDriver()` is idempotent (~50 ms when already installed, ~1.7 s fresh). | | |
| TASK-005 | Implement `SetAxis()` in `HidMaestroBackend`. Keep the `_steering` (-1..1), `_accelerator`/`_brake`/`_clutch` (0..1) fields with the same clamping as `ViGEmXboxBackend.cs:127-141`. On each call build the full frame via `HMGamepadStateHelpers.StandardAxes(ctrl.Profile, leftStickX: (_steering + 1f) / 2f, leftStickY: (_clutch + 1f) / 2f, leftTrigger: _accelerator, rightTrigger: _brake)` (SDK normalizes axes to `[0..1]`, 0.5 = center for signed axes) combined with the tracked buttons/hat from TASK-006, and call `ctrl.SubmitState(state)`. There is no SDK pump thread; the consumer drives cadence, so submit on every call. | | |
| TASK-006 | Implement `SetButton()` in `HidMaestroBackend`. Map `ButtonId.A/B/X/Y/LeftBumper/RightBumper/Back/Start/LeftThumb/RightThumb/Guide` → the corresponding `HMButton` flag bits (track in a local `HMButton _buttons` field). Map `ButtonId.DPadUp/DPadDown/DPadLeft/DPadRight` → the `HMHat` enum (North/South/West/East, combinations for diagonals), NOT button bits (the abstract `HMGamepadState` models the hat separately from the XUSB button-bit layout). Unknown `ButtonId` values are ignored (same as `ViGEmXboxBackend.cs:149-152`). Submit a complete `HMGamepadState` via `ctrl.SubmitState()` after each update. | | |
| TASK-007 | Implement `SendKey()` in `HidMaestroBackend` by delegating to `SendInputKeySimulator` (same pattern as `ViGEmXboxBackend`). | | |
| TASK-008 | Implement `Neutralize()` in `HidMaestroBackend`. Zero all tracked axes and buttons, reset hat to `HMHat.Centered`, release all keys via `SendInputKeySimulator`, and submit a neutral `HMGamepadState`. | | |
| TASK-009 | Implement `Shutdown()` in `HidMaestroBackend`. Call `Neutralize()`, then dispose the `HMController` (removes the virtual device via `DIF_REMOVE`) and dispose the `HMContext` (disposes owned controllers plus prewarm threads). | | |
| TASK-010 | Keep the `_lock` object pattern from `ViGEmXboxBackend` for thread safety. All public methods must acquire the lock before touching shared state. Note `HMController.OutputReceived` handlers (if subscribed) run on the SDK poll thread, not the UI thread. | | |

### Implementation Phase 3: Update composition root and setup checker

- GOAL-003: Rewire the factory and setup check to use the new backend instead of ViGEmBus.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-011 | In `desktop/WheelDeck.App/CompositionRoot.cs:112-125` (`CreateBackend()`), change the `OperatingSystem.IsWindows()` branch at line 116 from `return new ViGEmXboxBackend();` to `return new HidMaestroBackend();`. The Linux branch (`UinputBackend`) is untouched. | | |
| TASK-012 | In `desktop/WheelDeck.App/SetupChecker.cs:27-29`, update the Windows guidance message from "ViGEmBus is not installed or not reachable. Install ViGEmBus and retry." to "HIDMaestro driver is not installed or not reachable. The driver installs automatically on first use (administrator required). If installation fails, run as administrator and retry." | | |
| TASK-013 | Add a helper method `EnsureHidMaestroDriver()` to `SetupChecker.cs` that calls `HMContext.InstallDriver()` in a try/catch: `UnauthorizedAccessException` → "run as administrator" guidance; `InvalidOperationException` → surface `ex.Message`. This runs during setup check so the driver is installed before the backend initializes. | | |

### Implementation Phase 4: Remove ViGEmBus code

- GOAL-004: Delete the ViGEmBus P/Invoke bindings and the old backend implementation.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-014 | Delete `desktop/WheelDeck.Backends/Windows/ViGEmClient.cs` (the P/Invoke bindings to `ViGEmClient.dll`, 65 lines). | | |
| TASK-015 | Delete `desktop/WheelDeck.Backends/Windows/ViGEmXboxBackend.cs` (the old `VirtualOutputBackend` implementation, 267 lines). | | |
| TASK-016 | Run `dotnet build` and `dotnet test` from `desktop/` to verify no remaining references to ViGEmBus exist (`grep -r "ViGEm" desktop/WheelDeck.* --include="*.cs" --include="*.csproj"` returns empty) and the solution compiles cleanly. | | |

### Implementation Phase 5: Update documentation and setup scripts

- GOAL-005: Update all documentation references from ViGEmBus to HIDMaestro.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-017 | Update `CONTEXT.md:52` — change "Windows uses ViGEmBus" to "Windows uses HIDMaestro" in the VirtualOutputBackend glossary entry. | | |
| TASK-018 | Update `CONTEXT.md:79,82` — change "ViGEmBus" references in the setup check and setup scripts glossary entries to "HIDMaestro" (`check-vigembus.ps1` → `check-hidmaestro.ps1`, release-page offer → auto-install note). | | |
| TASK-019 | Update `docs/desktop-dev-guide.md:3` — change "Windows (ViGEmBus)" to "Windows (HIDMaestro)" in the introduction. | | |
| TASK-020 | Update `docs/desktop-dev-guide.md:10` — change the ViGEmBus prerequisite row to "HIDMaestro (Windows) \| n/a \| Auto-installs on first use via `HMContext.InstallDriver()` (admin required) — see `https://github.com/hifihedgehog/HIDMaestro`". | | |
| TASK-021 | Update `docs/desktop-dev-guide.md:117-123` — rewrite the Setup check section: Windows checks for the HIDMaestro driver (auto-install, admin required) instead of "checks for ViGEmBus driver. If missing, launches the browser to the official release page." | | |
| TASK-022 | Update `docs/desktop-dev-guide.md:127-133` — rewrite the Windows platform-specific setup section (`### Windows (ViGEmBus)` → `### Windows (HIDMaestro)`): driver auto-installs on first run (admin), manual fallback `scripts/windows/check-hidmaestro.ps1`, note `joy.cpl` shows "Controller (XBOX 360 For Windows)" while the process is alive. | | |
| TASK-023 | Update `docs/desktop-dev-guide.md:159-162` — change `check-vigembus.ps1` row to `check-hidmaestro.ps1`, purpose "Detects HIDMaestro driver state; install is automatic via the app (admin)". | | |
| TASK-024 | Update `docs/prd.md:39,74,79,101` — replace all ViGEmBus references with HIDMaestro. | | |
| TASK-025 | Update `docs/backend-interface.md:17,137` — replace ViGEmBus references. | | |
| TASK-026 | Update `docs/project-structure.md:53,62,70,93` — replace ViGEmBus references (`SetupChecker.cs` comment, `Windows/` comment, `check-vigembus.ps1` filename, rationale paragraph). | | |
| TASK-027 | Update `docs/adr/0004-degraded-continue-setup-check.md:3` — replace ViGEmBus reference. | | |
| TASK-028 | Update `docs/adr/0005-setup-scripts-detect-only.md:5` — replace ViGEmBus reference and note the ADR's detect-only rule is superseded on Windows by HIDMaestro auto-install (script becomes a status check). | | |
| TASK-029 | Update `README.md:17` — change "virtual Xbox controller (Windows/ViGEmBus)" to "virtual Xbox controller (Windows/HIDMaestro)". Do NOT touch line 58 (already correct: `Windows \| P1 \| HIDMaestro \| XBOX 360 Controller`). | | |
| TASK-030 | Rename `scripts/windows/check-vigembus.ps1` (79 lines) to `scripts/windows/check-hidmaestro.ps1` and rewrite: check HIDMaestro driver registration (`Get-PnpDevice` for `HIDMAESTRO*` / `pnputil /enum-drivers` for `hidmaestro.inf`) and `desktop/third_party/HIDMaestro/HIDMaestro.Core.dll` presence; report that install is automatic via the app (admin required). Remove the ViGEmBus release-page browser prompt. | | |
| TASK-031 | Update `plan/feature-wheeldeck-v1-1.md:26,77,102,155,186,208` — replace ViGEmBus references with HIDMaestro (CON-001, TASK-013, TASK-024, TASK-042, DEP-003, FILE-017). These are historical records of completed work; append a note that the backend was migrated per this plan rather than rewriting history. | | |
| TASK-032 | Update `desktop/README.md:7,21,30-32,44,85-87` — replace all ViGEmBus references (overview, SetupChecker comment, Windows tree `ViGEmClient.cs`/`ViGEmXboxBackend.cs` → `HidMaestroBackend.cs`, prerequisites table, Windows setup section) with HIDMaestro equivalents. | | |
| TASK-033 | Create `desktop/third_party/HIDMaestro/README.md` recording the vendored SDK release version, download URL, and SHA256 of `HIDMaestro.Core.dll` (written in TASK-001), plus the upstream repo link. | | |

## 3. Alternatives

- **ALT-001**: Keep ViGEmBus and fork it. Rejected because ViGEmBus requires an EV code-signing certificate ($300+/year) and a kernel driver, which HIDMaestro eliminates.
- **ALT-002**: Use WinUHid (user-mode, no kernel). Rejected because WinUHid is a framework requiring a custom HID descriptor and per-device C code, whereas HIDMaestro provides 228+ ready-made profiles with a managed C# SDK.
- **ALT-003**: Use libvirtualhid. Rejected because it requires a paid Windows driver license and does not yet support ARM64; HIDMaestro is MIT-licensed and feature-complete for game controllers.
- **ALT-004**: Use vJoy. Rejected because vJoy is stale, kernel-mode, and shows devices as "vJoy Device" instead of real hardware.
- **ALT-005**: Reference HIDMaestro via NuGet. Rejected because no NuGet feed exists as of 2026-09-11; upstream instructs consumers to reference `HIDMaestro.Core.dll` from a release ZIP or source build.

## 4. Dependencies

- **DEP-001**: `HIDMaestro.Core.dll` vendored SDK (MIT license, managed C# SDK + embedded UMDF2 driver payload, 228+ profiles). Source: HIDMaestro release ZIP or `scripts/build_all.cmd` from source. No NuGet feed as of 2026-09-11.
- **DEP-002**: .NET 10.0 SDK with Windows targeting pack; consuming projects target `net10.0-windows10.0.26100.0`, x64 only (SDK annotated `[SupportedOSPlatform("windows10.0.26100.0")]`).
- **DEP-003**: Administrator privileges (`SeLoadDriverPrivilege`) for `HMContext.InstallDriver()` and `CreateController()` on first run.

## 5. Files

- **FILE-001**: `desktop/third_party/HIDMaestro/HIDMaestro.Core.dll` — new file, vendored SDK (replaces NuGet approach).
- **FILE-002**: `desktop/third_party/HIDMaestro/README.md` — new file, SDK version + SHA256 record.
- **FILE-003**: `desktop/WheelDeck.Backends/Windows/WheelDeck.Backends.Windows.csproj` — retarget TFM + add DLL `<Reference>`.
- **FILE-004**: `desktop/WheelDeck.App/WheelDeck.App.csproj` — retarget TFM + add DLL `<Reference>`.
- **FILE-005**: `desktop/WheelDeck.Backends/Windows/HidMaestroBackend.cs` — new file, `VirtualOutputBackend` implementation using HIDMaestro.
- **FILE-006**: `desktop/WheelDeck.App/CompositionRoot.cs` — update `CreateBackend()` (line 116) to instantiate `HidMaestroBackend`.
- **FILE-007**: `desktop/WheelDeck.App/SetupChecker.cs` — update guidance message and add driver install check.
- **FILE-008**: `desktop/WheelDeck.Backends/Windows/ViGEmClient.cs` — delete.
- **FILE-009**: `desktop/WheelDeck.Backends/Windows/ViGEmXboxBackend.cs` — delete.
- **FILE-010**: `scripts/windows/check-vigembus.ps1` — rename to `check-hidmaestro.ps1` and rewrite.
- **FILE-011**: `CONTEXT.md` — update ViGEmBus → HIDMaestro (lines 52, 79, 82).
- **FILE-012**: `docs/desktop-dev-guide.md` — update all ViGEmBus references (lines 3, 10, 117-123, 127-133, 159-162).
- **FILE-013**: `docs/prd.md` — update ViGEmBus references (lines 39, 74, 79, 101).
- **FILE-014**: `docs/backend-interface.md` — update ViGEmBus references (lines 17, 137).
- **FILE-015**: `docs/project-structure.md` — update ViGEmBus references (lines 53, 62, 70, 93).
- **FILE-016**: `docs/adr/0004-degraded-continue-setup-check.md` — update ViGEmBus reference (line 3).
- **FILE-017**: `docs/adr/0005-setup-scripts-detect-only.md` — update ViGEmBus reference (line 5).
- **FILE-018**: `README.md` — update ViGEmBus reference (line 17; line 58 already correct).
- **FILE-019**: `desktop/README.md` — update ViGEmBus references (lines 7, 21, 30-32, 44, 85-87).
- **FILE-020**: `plan/feature-wheeldeck-v1-1.md` — update ViGEmBus references (lines 26, 77, 102, 155, 186, 208).

## 6. Testing

- **TEST-001**: Run `dotnet build` from `desktop/` — zero errors, zero warnings (excluding framework warnings).
- **TEST-002**: Run `dotnet test` from `desktop/` — all existing tests pass with no regressions.
- **TEST-003**: Manual smoke test on Windows (admin terminal) — launch the app, verify setup check reports "Virtual output backend is ready", verify a virtual Xbox 360 controller appears in joy.cpl as "Controller (XBOX 360 For Windows)" while the process is alive, verify ETS2/Steam recognizes the controller.
- **TEST-004**: Verify `Neutralize()` zeroes all axes/buttons/hat by inspecting the submitted `HMGamepadState` after `Neutralize()` call.
- **TEST-005**: Verify `SetAxis(AxisType.Steering, 0.5f)` produces leftStickX 0.75 in the submitted state (`(0.5 + 1) / 2`).
- **TEST-006**: Verify `SetButton(ButtonId.A, true)` sets the `HMButton.A` flag and `SetButton(ButtonId.DPadUp, true)` sets `Hat = HMHat.North` in the submitted state.
- **TEST-007**: Verify non-elevated launch surfaces the "run as administrator" guidance instead of an unhandled `UnauthorizedAccessException`.
- **TEST-008**: Verify `grep -r "ViGEmBus|ViGEm|vigem" docs/ CONTEXT.md README.md desktop/README.md plan/ scripts/windows/` returns only historical mentions (if any) after Phase 5.

## 7. Risks & Assumptions

- **RISK-001**: Vendored `HIDMaestro.Core.dll` goes stale with no NuGet feed to pull updates. Mitigation: record version + SHA256 in `desktop/third_party/HIDMaestro/README.md` (TASK-033) and re-vendor on each HIDMaestro release.
- **RISK-002**: `HMContext.InstallDriver()` / `CreateController()` require elevation. Mitigation: catch `UnauthorizedAccessException` in both backend and setup check and surface a clear "run as administrator" message (TASK-004, TASK-013, TEST-007).
- **RISK-003**: The `xbox-360-wired` profile must carry VID `0x045E` / PID `0x028E`. Mitigation: assert at startup after `GetProfile` (log actual `profile.VendorId`/`ProductId`); the quickstart confirms joy.cpl shows "Controller (XBOX 360 For Windows)".
- **RISK-004**: The `net10.0-windows10.0.26100.0` + x64-only requirement may break existing AnyCPU CI runners. Mitigation: pin the Windows build job to `windows-latest` + `x64`; Linux projects stay on `net10.0`.
- **RISK-005**: `HMButton` flag values and `HMHat` enum members may not cover every `ButtonId` (e.g. Guide). Mitigation: map what exists, ignore the rest, and log unmapped buttons during development.
- **ASSUMPTION-001**: HIDMaestro provides a managed C# API callable from a .NET 10.0 class library (verified: `HMContext`, `HMController`, `HMGamepadState`, `HMGamepadStateHelpers`, `HMButton`, `HMHat`, `HMAxis` per hidmaestro.org/docs/start/quickstart, 2026-09-11).
- **ASSUMPTION-002**: The `xbox-360-wired` profile id is stable across HIDMaestro releases (verified in quickstart + `HIDMaestroTest.exe emulate xbox-360-wired`).
- **ASSUMPTION-003**: HIDMaestro's `InstallDriver()` is idempotent and safe to call on every startup (verified: hash-checked, returns immediately when the same payload is installed).
- **ASSUMPTION-004**: `HMOemNameOverride.RecoverOrphans()` is safe to call on every startup (verified: returns count restored, per quickstart Step 0).

## 8. Related Specifications / Further Reading

- [HIDMaestro GitHub Repository](https://github.com/hifihedgehog/HIDMaestro)
- [HIDMaestro Installation (SDK vendoring + TFM requirements)](https://hidmaestro.org/docs/start/installation/)
- [HIDMaestro Quickstart (HMContext/HMGamepadState API)](https://hidmaestro.org/docs/start/quickstart/)
- [HIDMaestro Documentation](https://hidmaestro.org/)
- [PadForge HIDMaestro Deep Dive](https://padforge.org/docs/reference/hidmaestro-deep-dive/)
- [PadForge Driver Management](https://padforge.org/docs/features/driver-management/)
- [HIDMaestro Releases (SDK source)](https://github.com/hifihedgehog/HIDMaestro/releases)
- [ViGEmBus Retirement Context (LizardByte Issue #3527)](https://github.com/LizardByte/Sunshine/issues/3527)
