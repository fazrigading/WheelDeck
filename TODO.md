# TODO — Mobile & Desktop UI Revamp

Remember to update the future plan status to `draft` or `ongoing` or `finished`

## 1. branch: feature/rotatable-steering-and-dashboard

Rotatable means: finger-drag circular steering wheel.

- [x] Prepare the backend/system for the virtual steering wheel in windows and desktop, which will have two options: gyro or rotatable. If current system state already sufficient for the feature, it shouldn't be updated. (Wire unchanged; desktop steering untouched.)
- [x] For ETS2, rotatable is the default option, with 900 degrees.
- [x] add function for 180 degrees, 270 degrees, 1080 degrees, 1800 degrees, and 2520 degrees.
- [x] Change the `controller type` options to toggle (hide/show) for Clutch and Dashboard; except Steering Wheel, Acceleration, and Brake.
- [x] Steering Wheel has a toggle for `Rotatable` or `Gyro`
- [x] create a visual indicator for the rotation in mobile-view
- [x] create a desktop widget showing the wheel rotation for manual testing, only enabled when pressed the button.

---

## 2. dashboard revamp (same branch, see plan phases 4-7) :

References of the dashboard images can be viewed at `plan/references/`.

- [x] Light modes actually has 2 modes (Parking Lights & Low Beam), so toggling it should change the button visually: OFF -> Parking Lights -> Low Beam; High-Beam stay independent.
- [x] Blinking button for Left-Right Turn Signal

### a. Fix existing buttons:
- [x] Decrease the size of all dashboard buttons
- [x] Change "Cruise Toggle" keybind to `C`
- [x] Change "Cruise set/resume" to "Cruise Resume", keybind is set-able
- [x] Change "HI/Hl" button name to "High-beam" keybind to `K`

### b. Add New Buttons:
- [x] "Hazard Lights" (`F`)
- [x] "Warning / Beacon Lights" (`O`)
- [x] "Light Horn / Flasher" (`J`)
- [x] "Horn" in the dashboard grid (`H`)
- [x] "Trailer" (`T`)
- [x] "Lift / Drop Axle" (`U`)
- [x] "Camera View" (`9`)

#### b.1. Create toggle for these buttons in the Settings page (These toggle should follow the M3 design guideline):
- [x] For each pedal in `Pedal Layout`, second toggle appear: **Left** or **Right**.
- [x] `Engine Start` toggle must be either **hold** or **press** to turn on engine.
- [x] Gear Up (`Left Shift`)
- [x] Gear Down (`Left Ctrl`)
- [x] Engine Brake (`B`)
- [x] Air Horn (`N`)
- [x] Differential Lock (`V`)
- [x] Retarder Increase (`;`)
- [x] Retarder Decrease (`'`)
- [x] Quick Info (`F1`)
- [x] Mirror Toggle (`F2`)
- [x] HUD Widgets (`F3`)
- [x] Vehicle Adjustment (`F4`)
- [x] Navigation Zoom Out (`F5`)
- [x] Widget Options (`F6`)
- [x] Services & Adjustments (`F7`)
- [x] Quick Save (`Scroll Lock`)
- [x] Quick Load (`Pause`)
- [x] Screenshot (`F10`)
- [x] Garage Manager (`G`)
- [x] Audio/Radio Player (`R`)

##### b.2. Set-able keybinds by user (default to empty keybinds):
- [x] Shift to Drive
- [x] Shift to Reverse
- [x] Shift to Neutral
- [x] Start/Stop Engine Electricity
- [x] Adaptive Cruise Control Mode
- [x] Cruise Control Speed Increase
- [x] Cruise Control Speed Decrease
- [x] Lane Assistant Mode
- [x] Lane Keeping Assistant
- [x] Emergency Brake
- [x] Wipers Back
- [x] Audio Player Play/Pause
- [x] Audio Player Next
- [x] Audio Player Previous
- [x] Audio Player Volume Up
- [x] Audio Player Volume Down
- [x] Audio Player Add to/Remove From Favorites

### c. In Gyro-mode:
- [x] Steering wheel should shown in the middle with indicator of X-axis line under it (dashboard OFF).
- [x] Selected pedal layout option should put each pedal in its preferred location, e.g. `Brake` toggled to `Left` means the `Brake` pedal placed at left side, not beside of the `Accelerator` pedal at the right side.
- [x] If dashboard toggled ON in gyro-mode, drop the steering wheel and show only the horizontal tilt readout at top-center; dashboard shown in remaining space.
- [x] L/R turn-signal arrows sit above the left pedal (not in the dashboard grid); dashboard grid never shows L/R.

### d. In Rotatable-mode:
- [x] Steering wheel must be placed in bottom-left corner, with size 50% of the device width resolution.
- [x] Turn Signals placed above the steering wheel as left/right arrow icons that blink (replaces dashboard-grid L/R, which are removed entirely).
- [x] Pedal layout (Accelerate and Brake) must placed on bottom-right of the screen, if Clutch pedal turned on, must placed on top-left above the turn signals.
- [x] If `Gear Up` and `Gear Down` are toggled ON, both must be placed vertically above of the pedals (top-right corner).
