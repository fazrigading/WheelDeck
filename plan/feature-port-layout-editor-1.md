---
goal: Port the layout editor, layout profiles, edit API, and layout presets (Simple Automatic, Real Automatic, H-Shifter) from Flutter to Kotlin
version: 1.0
date_created: 2026-10-16
last_updated: 2026-10-16
owner: Fazri Gading
status: 'Draft'
tags: [feature, mobile, android, kotlin, layout, editor]
---

# Introduction

This plan covers porting the dashboard layout editor, custom profiles, and additional transmission presets from the Flutter reference implementation (`backup/flutter-port` / `plan/feature-custom-button-layout-1.md`) into the Kotlin Compose Android application.

Currently, the Android app only supports a hardcoded `Sequential` layout without editing capabilities or alternative presets.

## Background & Reference

- Reference Dart sources: `mobile/lib/data/services/layout_profile.dart`, `mobile/lib/data/models/driving_layout.dart` on branch `backup/flutter-port`.
- Relevant tests to port: `driving_layout_edit_test.dart`, `layout_profile_test.dart`.
- Tracked in `tasks/task-12-leftovers.md` and `TODO.md` under regressions from cutover.

## Scope & Deliverables

1. **Layout Edit Domain API**:
   - Port slot mutation and layout arithmetic: `applyMove`, `addControl`, `removeSlot`, `freeSpans`.
   - Grid validation and collision avoidance for block/cell placements.
2. **Layout Presets**:
   - Port `Simple Automatic`, `Real Automatic`, and `H-Shifter` presets alongside existing `Sequential`.
   - Re-enable the layout-dependent setting behavior (e.g. conditionally showing the camera pad configuration only when the layout contains a camera pad slot).
3. **LayoutProfileStore**:
   - Persist custom and active profiles via Android DataStore/JSON.
   - Profile CRUD (create, clone preset, rename, delete, reset to default).
4. **Layout Editor UI in Jetpack Compose**:
   - Interactive drag/reposition or tap-to-swap interface for dashboard controls.
   - Unbound/free cell indicator, control picker palette.
   - Settings integration: Layout selection screen and profile manager.
5. **Unit Tests**:
   - Port test suites for grid mutations, layout overlaps, and profile persistence with JUnit.
