# WheelDeck project structure

## Repository layout

Single monorepo covering the mobile app, the desktop server, and the shared protocol definitions.

```
WheelDeck/
├── docs/
│   ├── prd.md
│   ├── backend-interface.md
│   ├── mobile-interface.md
│   ├── project-structure.md
│   ├── desktop-dev-guide.md
│   ├── mobile-dev-guide.md
│   └── adr/
│
├── protocol/
│   └── schema/
│       ├── state_message.json
│       ├── button_message.json
│       ├── session_messages.json
│       └── controls.json
│
├── mobile/
│   ├── lib/
│   │   ├── main.dart                      # Entry point, Provider scope, routing
│   │   ├── input/
│   │   │   ├── steering_sensor.dart       # Gyroscope → -1..1 normalized value
│   │   │   ├── pedal_input.dart           # Touch-to-pressure mapping, spring-back
│   │   │   └── dashboard_input.dart       # ControlId/ActionType enums from schema
│   │   ├── network/
│   │   │   ├── wheeldeck_client.dart      # WebSocket connection + message framing
│   │   │   ├── discovery.dart             # mDNS auto-discovery + manual IP fallback
│   │   │   └── pairing.dart               # PIN pairing + session token persistence
│   │   ├── ui/
│   │   │   ├── connection/                # Discovery, IP entry, pairing screens
│   │   │   ├── driving/                   # Combined driving surface
│   │   │   ├── wheel/                     # On-screen wheel + calibration
│   │   │   ├── pedals/                    # Vertical draggable pedal bars
│   │   │   ├── dashboard/                 # Truck-styled control panel
│   │   │   └── permissions.dart           # Onboarding permission prompts
│   │   └── state/
│   │       └── connection_coordinator.dart # Connection lifecycle state machine
│   ├── android/
│   ├── ios/
│   ├── test/
│   └── pubspec.yaml
│
├── desktop/
│   ├── WheelDeck.sln
│   ├── WheelDeck.App/              # Avalonia UI + composition root
│   │   ├── Program.cs              # Entry point (GUI or --daemon)
│   │   ├── CompositionRoot.cs      # DI, picks VirtualOutputBackend by OS
│   │   ├── SetupChecker.cs         # First-run ViGEmBus/uinput check
│   │   ├── Views/                  # XAML views
│   │   └── ViewModels/             # MVVM view models
│   ├── WheelDeck.Core/             # Domain logic (no OS dependencies)
│   │   ├── Protocol/               # Message models from protocol/schema/
│   │   ├── Pairing/                # PairingManager, IPairingStore, session tokens
│   │   ├── Input/                  # InputMapper, MappingMode
│   │   └── Network/                # WebSocketListener, PairingService, SessionGate, HeartbeatMonitor
│   ├── WheelDeck.Backends/
│   │   ├── Windows/                # ViGEmBus virtual Xbox 360 controller
│   │   └── Linux/                  # uinput virtual joystick
│   └── WheelDeck.Tests/            # xunit unit tests
│
├── scripts/
│   ├── linux/
│   │   └── install-uinput-rules.sh
│   └── windows/
│       └── check-vigembus.ps1
│
├── .github/
│   └── workflows/
│       ├── mobile-ci.yml
│       └── desktop-ci.yml
│
├── LICENSE
└── README.md
```

## Directory rationale

### protocol/

Both backend-interface.md and mobile-interface.md describe the same message formats and control enums independently. That is fine for docs, but two hand-maintained copies of the same enum will drift in code. protocol/schema/ is the single source of truth. Both mobile/ and desktop/ generate or reference their language-specific types from these files instead of defining them twice. This prevents the exact bug where a new dashboard control gets added on one side and forgotten on the other.

### desktop/WheelDeck.Backends/

Kept as separate projects per platform (Windows/, Linux/) rather than one project with runtime OS checks scattered through it. Each implements the VirtualOutputBackend interface from backend-interface.md. WheelDeck.Core depends only on the interface, never on a specific backend. The composition root (WheelDeck.App) picks the right implementation at startup based on the running OS. This is what makes "drop macOS support for now, add it later" cheap. A new folder implementing the same interface, not a rewrite.

### scripts/

First-run setup friction is called out as a non-functional requirement in the PRD: verify ViGEmBus or uinput permissions instead of failing silently. These scripts are what the WheelDeck.App first-run check runs automatically or points the user to. They are also useful to run manually during development on Fedora.

### mobile/lib/ internal layout

Mirrors the three-layer structure from mobile-interface.md directly: input/ is the Input Capture Layer, network/ is the Network Client Layer, ui/ is the UI Layer. Keeping the folder structure and the interface doc's layer names identical means you can go from "which layer does this bug belong to" straight to "which folder".

### CI split

Separate mobile-ci.yml and desktop-ci.yml rather than one combined workflow. They build on different runners: Flutter tooling vs. .NET plus platform-specific driver dependencies for backend tests. A mobile-only change should not wait on a full desktop build matrix, or the reverse.

## Not included yet

No ios/ signing config, no installer or packaging scripts, no CONTRIBUTING.md. These matter once there is working code to ship, not before. Add them after initial prototyping, not as part of this structure decision.
