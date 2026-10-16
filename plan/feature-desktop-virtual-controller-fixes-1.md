---
goal: Fix camera pad Gamepad mode bindings, improve Linux uinput/Steam Input controller detection and hardware profile spoofing, and fix desktop wheel monitor needle rendering
version: 1.0
date_created: 2026-10-16
last_updated: 2026-10-16
owner: Fazri Gading
status: 'Draft'
tags: [feature, desktop, linux, uinput, input, gamepad]
---

# Introduction

This plan addresses desktop-side input mapping gaps and controller integration issues documented in `TODO.md` and `tasks/task-12-leftovers.md`.

## Problems & Scope

1. **Camera Pad Gamepad Mode Discard Bug**:
   - In `desktop/WheelDeck.Core/Input/InputMapper.cs:223-235`, all 13 `camera_pad_*` controls map to `ButtonId.None` when `InputMapping.fallback` is `Gamepad`.
   - On a default install, pad controls send messages that the desktop discards.
   - Solution: Assign proper virtual gamepad buttons / axes or allow fallback to keyboard mode for unbound pad controls so they function out of the box.
2. **Linux uinput Virtual Device & Steam Input Detection**:
   - On Linux (Fedora), Steam detects "WheelDeck Virtual Controller" only as generic unless Steam Input is forced; games fail to identify it as a valid steering wheel or standard gamepad.
   - Investigate device descriptor tuning, virtual device properties (bus type, vendor/product IDs), or configurable Hardware ID profiles (e.g. MOZA TSW Truck Wheel, Logitech G923) mapped to selected rotation degrees.
3. **Desktop Wheel Monitor Needle Rendering**:
   - The desktop wheel monitor UI is active and receives steering values, but the needle graphic fails to rotate or animate as expected.
   - Fix Avalonia UI binding, rotation transform, or interpolation logic in `WheelMonitorViewModel` and its view.
4. **Verification**:
   - C# unit tests for `InputMapper` camera pad mappings.
   - Test virtual controller output under Linux uinput and verify Avalonia monitor needle responsiveness.
