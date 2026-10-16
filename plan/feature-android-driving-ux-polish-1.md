---
goal: Implement Camera Pad Simple and Analog shape renderers, restore gyro-mode signal row, and lock driving screen to landscape orientation
version: 1.0
date_created: 2026-10-16
last_updated: 2026-10-16
owner: Fazri Gading
status: 'Draft'
tags: [feature, mobile, android, kotlin, ui, controls]
---

# Introduction

This plan covers resolving the remaining mobile driving UI and control gaps noted in `TODO.md` and `tasks/task-12-leftovers.md` following the Kotlin cutover.

## Scope & Deliverables

1. **Camera Pad Shape Renderers**:
   - Currently, `CameraControlType` (D-pad, Simple, Analog) is selectable in Settings and persisted in DataStore, but the driving view only renders the D-pad interface.
   - Implement Compose renderers for `Simple` (compact directional pad / touch zone) and `Analog` (virtual thumbstick / joystick with continuous deflection).
2. **Gyro Mode Layout & Turn Signal Row**:
   - Port the missing gyro driving screen layout components from Flutter (`_signalRow()` in `driving_view.dart:420`).
   - Render turn signal controls above the left pedal column in gyro mode, respecting light/hazard states and pedal visibility.
3. **Screen Orientation Lock**:
   - Enforce landscape orientation specifically while on the driving screen (`DrivingScreen`).
   - Restore natural / system sensor orientation when navigating back to Settings, Pairing, or Menu screens.
4. **Testing & Verification**:
   - Unit tests for touch deflection mapping in Analog mode and touch bounds in Simple mode.
   - Verify layout placement contracts for gyro mode signal cells.
