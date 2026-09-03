# WheelDeck

Turn an Android or iOS phone into a steering wheel and dashboard control panel for PC racing and trucking simulators. A desktop companion app translates the phone's input into a virtual game controller the simulator reads natively.

Primary target: Euro Truck Simulator 2.

## Components

- `mobile/` - Flutter app that captures steering, pedals, and dashboard controls.
- `desktop/` - C#/.NET with Avalonia UI; exposes a virtual controller on Windows (ViGEmBus) and Linux (uinput).
- `protocol/schema/` - Shared JSON schemas, the single source of truth for control enums and message shapes.

## Docs

The specs live in `docs/`:

- `prd.md` - product requirements
- `backend-interface.md` - desktop server interfaces
- `mobile-interface.md` - mobile app interfaces
- `project-structure.md` - repository layout and rationale

See the implementation plan in `plan/feature-wheeldeck-v1-1.md`.
