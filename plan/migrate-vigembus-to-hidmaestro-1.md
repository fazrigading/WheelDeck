---
goal: Migrate the Windows virtual controller backend from ViGEmBus (retired, kernel-mode) to HIDMaestro (active, user-mode UMDF2)
version: '1.0'
date_created: '2026-09-05'
owner: ''
status: 'Planned'
tags:
  - migration
  - infrastructure
  - upgrade
---

# Introduction

![Status: Planned](https://img.shields.io/badge/status-Planned-blue)

Migrate the Windows virtual controller backend from ViGEmBus to HIDMaestro. ViGEmBus is retired and requires a kernel driver plus an EV code-signing certificate for new builds. HIDMaestro is a user-mode UMDF2 driver with a managed C# SDK, 231+ device profiles, and no kernel dependency. The `VirtualOutputBackend` interface in `WheelDeck.Core` decouples business logic from the driver, making this a targeted swap of the Windows backend implementation.

## 1. Requirements & Constraints

- **REQ-001**: The Windows backend must produce a virtual Xbox 360 controller recognizable by XInput and DirectInput.
- **REQ-002**: All existing `VirtualOutputBackend` methods must continue to work identically: `Initialize()`, `SetAxis()`, `SetButton()`, `SendKey()`, `Neutralize()`, `Shutdown()`.
- **REQ-003**: The virtual controller must present VID `0x045E` and PID `0x028E` (Xbox 360 Controller for Windows) to match current behavior.
- **REQ-004**: No changes to `WheelDeck.Core` or `WheelDeck.Backends.Linux` are permitted.
- **REQ-005**: Keyboard simulation via `SendInputKeySimulator` must remain unchanged.
- **SEC-001**: The new backend must not introduce any network listeners or open ports.
- **SEC-002**: The HIDMaestro driver runs in user mode (UMDF2); no kernel-mode code is introduced.
- **CON-001**: HIDMaestro requires .NET 10.0 runtime on Windows (x64). ARM64 support is not yet available.
- **CON-002**: HIDMaestro requires administrator privileges for `InstallDriver()`. The setup check must handle this.
- **CON-003**: The migration must not break the Linux uinput backend or the `CompositionRoot` OS-conditional factory.
- **GUD-001**: Follow existing P/Invoke→managed SDK pattern: replace raw DllImport with HIDMaestro's managed API.
- **GUD-002**: All new code must pass `dotnet build` with zero warnings and `dotnet test` with all tests passing.
- **PAT-001**: Backends are split per platform (`Windows/`, `Linux/`) behind the `VirtualOutputBackend` interface. The Core project never references a specific backend. This pattern is preserved.

## 2. Implementation Steps

### Implementation Phase 1: Add HIDMaestro SDK dependency

- GOAL-001: Wire the HIDMaestro NuGet package into the Windows backend project so the new backend can reference its managed API.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-001 | Add the `HIDMaestro.Core` NuGet package reference to `WheelDeck.Backends.Windows.csproj`. Target version: latest stable (check NuGet for current version). The package provides `HIDMaestro.Core.dll` with the `HMContext` and controller API. | | |
| TASK-002 | Add the `HIDMaestro.Core` NuGet package reference to `WheelDeck.App.csproj` as well, since the composition root and setup checker will call `HMContext` for driver installation. | | |
| TASK-003 | Run `dotnet restore` and `dotnet build` from `desktop/` to verify the package resolves and the solution compiles. Fix any framework compatibility issues (both projects target `net10.0`). | | |

### Implementation Phase 2: Create the new HIDMaestro backend

- GOAL-002: Replace `ViGEmXboxBackend` with `HidMaestroBackend` implementing the same `VirtualOutputBackend` interface using the HIDMaestro managed SDK.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-004 | Create `WheelDeck.Backends/Windows/HidMaestroBackend.cs`. Implement `VirtualOutputBackend`. In `Initialize()`: create an `HMContext`, load default profiles, call `InstallDriver()`, then instantiate a virtual Xbox 360 controller using the built-in Xbox 360 wired profile (VID `0x045E`, PID `0x028E`). Return `BackendResult.Failure(...)` with descriptive error if any step fails. | | |
| TASK-005 | Implement `SetAxis()` in `HidMaestroBackend`. Map `AxisType.Steering` → left stick X, `AxisType.Accelerator` → left trigger, `AxisType.Brake` → right trigger, `AxisType.Clutch` → left stick Y. Use the HIDMaestro report builder API to construct and submit the Xbox 360 HID report on each call. | | |
| TASK-006 | Implement `SetButton()` in `HidMaestroBackend`. Map all `ButtonId` values to the corresponding Xbox 360 button bits. Track button state locally and submit a complete report after each update. | | |
| TASK-007 | Implement `SendKey()` in `HidMaestroBackend` by delegating to `SendInputKeySimulator` (same pattern as `ViGEmXboxBackend`). | | |
| TASK-008 | Implement `Neutralize()` in `HidMaestroBackend`. Zero all tracked axes and buttons, release all keys via `SendInputKeySimulator`, and submit a neutral HID report. | | |
| TASK-009 | Implement `Shutdown()` in `HidMaestroBackend`. Call `Neutralize()`, then dispose of the `HMContext` and any HIDMaestro resources. | | |
| TASK-010 | Keep the `_lock` object pattern from `ViGEmXboxBackend` for thread safety. All public methods must acquire the lock before touching shared state. | | |

### Implementation Phase 3: Update composition root and setup checker

- GOAL-003: Rewire the factory and setup check to use the new backend instead of ViGEmBus.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-011 | In `CompositionRoot.cs:69-82`, change the `OperatingSystem.IsWindows()` branch to instantiate `HidMaestroBackend` instead of `ViGEmXboxBackend`. | | |
| TASK-012 | In `SetupChecker.cs:27-29`, update the Windows guidance message from "ViGEmBus is not installed or not reachable. Install ViGEmBus and retry." to "HIDMaestro driver is not installed or not reachable. The driver will install automatically on first use. If installation fails, run as administrator and retry." | | |
| TASK-013 | Add a helper method `EnsureHidMaestroDriver()` to `SetupChecker.cs` that attempts `HMContext.InstallDriver()` in a try/catch. If it throws (e.g., not running as admin), surface a clear error message. This runs during setup check so the driver is installed before the backend initializes. | | |

### Implementation Phase 4: Remove ViGEmBus code

- GOAL-004: Delete the ViGEmBus P/Invoke bindings and the old backend implementation.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-014 | Delete `WheelDeck.Backends/Windows/ViGEmClient.cs` (the P/Invoke bindings to `ViGEmClient.dll`). | | |
| TASK-015 | Delete `WheelDeck.Backends/Windows/ViGEmXboxBackend.cs` (the old `VirtualOutputBackend` implementation). | | |
| TASK-016 | Run `dotnet build` and `dotnet test` to verify no remaining references to ViGEmBus exist and the solution compiles cleanly. | | |

### Implementation Phase 5: Update documentation and setup scripts

- GOAL-005: Update all documentation references from ViGEmBus to HIDMaestro.

| Task | Description | Completed | Date |
|------|-------------|-----------|------|
| TASK-017 | Update `CONTEXT.md:52` — change "Windows uses ViGEmBus" to "Windows uses HIDMaestro" in the VirtualOutputBackend glossary entry. | | |
| TASK-018 | Update `CONTEXT.md:79,82` — change "ViGEmBus" references in the setup check and setup scripts glossary entries to "HIDMaestro". | | |
| TASK-019 | Update `docs/desktop-dev-guide.md:3` — change "Windows (ViGEmBus)" to "Windows (HIDMaestro)" in the introduction. | | |
| TASK-020 | Update `docs/desktop-dev-guide.md:13,14` — change the ViGEmBus prerequisite to "HIDMaestro (Windows) | n/a | Auto-installs on first use (or `https://github.com/hifihedgehog/HIDMaestro`)". | | |
| TASK-021 | Update `docs/desktop-dev-guide.md:63-64` — change "ViGEmBus implementation (ViGEm.NET)" to "HIDMaestro implementation" in the project structure tree. | | |
| TASK-022 | Update `docs/desktop-dev-guide.md:173-179` — rewrite the Windows platform-specific setup section to describe HIDMaestro auto-installation and manual fallback. | | |
| TASK-023 | Update `docs/desktop-dev-guide.md:207` — change `check-vigembus.ps1` references to `check-hidmaestro.ps1` and update the script purpose. | | |
| TASK-024 | Update `docs/prd.md` — replace all ViGEmBus references with HIDMaestro (lines 39, 74, 79, 101). | | |
| TASK-025 | Update `docs/backend-interface.md` — replace ViGEmBus references (lines 17, 137). | | |
| TASK-026 | Update `docs/project-structure.md` — replace ViGEmBus references (lines 49, 57, 80). | | |
| TASK-027 | Update `docs/adr/0004-degraded-continue-setup-check.md` — replace ViGEmBus reference (line 3). | | |
| TASK-028 | Update `docs/adr/0005-setup-scripts-detect-only.md` — replace ViGEmBus reference (line 5). | | |
| TASK-029 | Update `README.md` — replace ViGEmBus reference (line 10). | | |
| TASK-030 | Rename `scripts/windows/check-vigembus.ps1` to `scripts/windows/check-hidmaestro.ps1` and rewrite its content to detect HIDMaestro (check for `HIDMaestro.Core.dll` in the app directory or check driver registration via `HMContext`). | | |
| TASK-031 | Update the existing plan `plan/feature-wheeldeck-v1-1.md` — replace ViGEmBus references with HIDMaestro (lines 26, 77, 102, 155, 187, 209). | | |

## 3. Alternatives

- **ALT-001**: Keep ViGEmBus and fork it. Rejected because ViGEmBus requires an EV code-signing certificate ($300+/year) and a kernel driver, which HIDMaestro eliminates.
- **ALT-002**: Use WinUHid (user-mode, no kernel). Rejected because WinUHid is a framework requiring a custom HID descriptor and per-device C code, whereas HIDMaestro provides 231+ ready-made profiles with a managed C# SDK.
- **ALT-003**: Use libvirtualhid. Rejected because it requires a paid Windows driver license and does not yet support ARM64; HIDMaestro is MIT-licensed and feature-complete for game controllers.
- **ALT-004**: Use vJoy. Rejected because vJoy is stale, kernel-mode, and shows devices as "vJoy Device" instead of real hardware.

## 4. Dependencies

- **DEP-001**: `HIDMaestro.Core` NuGet package (MIT license, managed C# SDK for the HIDMaestro UMDF2 driver).
- **DEP-002**: .NET 10.0 runtime on Windows x64 (HIDMaestro annotated `[SupportedOSPlatform("windows10.0.26100.0")]`).
- **DEP-003**: Administrator privileges for `HMContext.InstallDriver()` on first run.

## 5. Files

- **FILE-001**: `desktop/WheelDeck.Backends/Windows/WheelDeck.Backends.Windows.csproj` — add HIDMaestro.Core NuGet reference.
- **FILE-002**: `desktop/WheelDeck.App/WheelDeck.App.csproj` — add HIDMaestro.Core NuGet reference.
- **FILE-003**: `desktop/WheelDeck.Backends/Windows/HidMaestroBackend.cs` — new file, `VirtualOutputBackend` implementation using HIDMaestro.
- **FILE-004**: `desktop/WheelDeck.App/CompositionRoot.cs` — update `CreateBackend()` to instantiate `HidMaestroBackend`.
- **FILE-005**: `desktop/WheelDeck.App/SetupChecker.cs` — update guidance message and add driver install check.
- **FILE-006**: `desktop/WheelDeck.Backends/Windows/ViGEmClient.cs` — delete.
- **FILE-007**: `desktop/WheelDeck.Backends/Windows/ViGEmXboxBackend.cs` — delete.
- **FILE-008**: `scripts/windows/check-vigembus.ps1` — rename to `check-hidmaestro.ps1` and rewrite.
- **FILE-009**: `CONTEXT.md` — update ViGEmBus → HIDMaestro.
- **FILE-010**: `docs/desktop-dev-guide.md` — update all ViGEmBus references.
- **FILE-011**: `docs/prd.md` — update ViGEmBus references.
- **FILE-012**: `docs/backend-interface.md` — update ViGEmBus references.
- **FILE-013**: `docs/project-structure.md` — update ViGEmBus references.
- **FILE-014**: `docs/adr/0004-degraded-continue-setup-check.md` — update ViGEmBus reference.
- **FILE-015**: `docs/adr/0005-setup-scripts-detect-only.md` — update ViGEmBus reference.
- **FILE-016**: `README.md` — update ViGEmBus reference.
- **FILE-017**: `plan/feature-wheeldeck-v1-1.md` — update ViGEmBus references.

## 6. Testing

- **TEST-001**: Run `dotnet build` from `desktop/` — zero errors, zero warnings (excluding framework warnings).
- **TEST-002**: Run `dotnet test` from `desktop/` — all existing tests pass with no regressions.
- **TEST-003**: Manual smoke test on Windows — launch the app, verify setup check reports "Virtual output backend is ready", verify a virtual Xbox 360 controller appears in joy.cpl, verify ETS2/Steam recognizes the controller.
- **TEST-004**: Verify `Neutralize()` zeroes all axes and buttons by inspecting the HID report after `Neutralize()` call.
- **TEST-005**: Verify `SetAxis(AxisType.Steering, 0.5f)` produces the correct stick X value in the HID report.
- **TEST-006**: Verify `SetButton(ButtonId.A, true)` produces the correct button bit in the HID report.

## 7. Risks & Assumptions

- **RISK-001**: HIDMaestro's managed API may differ from the examples in its documentation. Mitigation: read the actual `HIDMaestro.Core.dll` API surface via decompilation or by referencing the PadForge source for integration patterns.
- **RISK-002**: `HMContext.InstallDriver()` may require the app to run elevated (administrator). Mitigation: the app already runs as a desktop app; if elevation is required, the setup check must surface a clear "run as administrator" message.
- **RISK-003**: HIDMaestro may not support the exact Xbox 360 VID/PID combination needed. Mitigation: the built-in `xbox-360-wired` profile should match; verify against the profile catalog.
- **RISK-004**: The .NET 10.0 target framework may not be compatible with HIDMaestro's platform annotations. Mitigation: HIDMaestro targets `net10.0-windows10.0.26100.0`; verify compatibility or adjust the csproj `TargetFramework` if needed.
- **ASSUMPTION-001**: HIDMaestro provides a managed C# API (not just P/Invoke) that can be called from a .NET 10.0 class library.
- **ASSUMPTION-002**: The `xbox-360-wired` profile in HIDMaestro reports VID `0x045E` and PID `0x028E`.
- **ASSUMPTION-003**: HIDMaestro's `InstallDriver()` is idempotent and safe to call multiple times.

## 8. Related Specifications / Further Reading

- [HIDMaestro GitHub Repository](https://github.com/hifihedgehog/HIDMaestro)
- [HIDMaestro Documentation](https://hidmaestro.org/)
- [PadForge HIDMaestro Deep Dive](https://padforge.org/docs/reference/hidmaestro-deep-dive/)
- [PadForge Driver Management](https://padforge.org/docs/features/driver-management/)
- [HIDMaestro Releases](https://github.com/hifihedgehog/HIDMaestro/releases)
- [ViGEmBus Retirement Context (LizardByte Issue #3527)](https://github.com/LizardByte/Sunshine/issues/3527)
