# TODO — Mobile & Desktop UI Revamp

Remember to update the future plan status to `draft` or `ongoing` or `finished`

## 1. branch: feature/rotatable-steering-mode

Rotatable means: finger-drag circular steering wheel.

- [ ] Prepare the backend/system for the virtual steering wheel in windows and desktop, which will have two options: gyro or rotatable. If current system state already sufficient for the feature, it shouldn't be updated.
- [ ] For ETS2, rotatable is the default option, with 900 degrees. 
- [ ] add function for 180 degrees, 270 degrees, 1080 degrees, 1800 degrees, and 2520 degrees.
- [ ] Change the `controller type` options to toggle (hide/show) for Clutch and Dashboard; except Steering Wheel, Acceleration, and Brake.
- [ ] Steering Wheel has a toggle for `Rotatable` or `Gyro`
- [ ] create a visual indicator for the rotation in mobile-view
- [ ] create a desktop widget showing the wheel rotation for manual testing, only enabled when pressed the button.

---

## 2. branch `feature/revamp-dashboard` :

References of the dashboard images can be viewed at `plan/references/`.

- [ ] Light modes actually has 2 modes (Parking Lights & Low Beam), so toggling it should change the button visually: OFF -> Parking Lights -> Low Beam; High-Beam stay independent.
- [ ] Blinking button for Left-Right Turn Signal

### a. Fix existing buttons:
- [ ] Decrease the size of all dashboard buttons
- [ ] Change "Cruise Toggle" keybind to `C`
- [ ] Change "Cruise set/resume" to "Cruise Resume", keybind is set-able 
- [ ] Change "HI/Hl" button name to "High-beam" keybind to `K`

### b. Add New Buttons:
- [ ] "Hazard Lights" (`F`)
- [ ] "Warning / Beacon Lights" (`O`)
- [ ] "Light Horn / Flasher" (`J`)
- [ ] "Horn" in the dashboard grid (`H`)
- [ ] "Trailer" (`T`) 
- [ ] "Lift / Drop Axle" (`U`)
- [ ] "Camera View" (`9`)

#### b.1. Create toggle for these buttons in the Settings page (These toggle should follow the M3 design guideline):
- [ ] For each pedal in `Pedal Layout`, second toggle appear: **Left** or **Right**.
- [ ] `Engine Start` toggle must be either **hold** or **press** to turn on engine.
- [ ] Gear Up (`Left Shift`)
- [ ] Gear Down (`Left Ctrl`)
- [ ] Engine Brake (`B`)
- [ ] Air Horn (`N`)
- [ ] Differential Lock (`V`)
- [ ] Retarder Increase (`;`)
- [ ] Retarder Decrease (`'`)
- [ ] Quick Info (`F1`)
- [ ] Mirror Toggle (`F2`)
- [ ] HUD Widgets (`F3`)
- [ ] Vehicle Adjustment (`F4`)
- [ ] Navigation Zoom Out (`F5`)
- [ ] Widget Options (`F6`)
- [ ] Services & Adjustments (`F7`)
- [ ] Quick Save (`Scroll Lock`)
- [ ] Quick Load (`Pause`)
- [ ] Screenshot (`F10`)
- [ ] Garage Manager (`G`)
- [ ] Audio/Radio Player (`R`)

##### b.2. Set-able keybinds by user (default to empty keybinds):
- [ ] Shift to Drive
- [ ] Shift to Reverse
- [ ] Shift to Neutral
- [ ] Start/Stop Engine Electricity
- [ ] Adaptive Cruise Control Mode
- [ ] Cruise Control Speed Increase
- [ ] Cruise Control Speed Decrease
- [ ] Lane Assistant Mode
- [ ] Lane Keeping Assistant
- [ ] Emergency Brake
- [ ] Wipers Back
- [ ] Audio Player Play/Pause
- [ ] Audio Player Next
- [ ] Audio Player Previous
- [ ] Audio Player Volume Up
- [ ] Audio Player Volume Down
- [ ] Audio Player Add to/Remove From Favorites

### c. In Gyro-mode: 
- [ ] Steering wheel should shown in the middle with indicator of X-axis line under it (dashboard OFF). 
- [ ] Selected pedal layout option should put each pedal in its preferred location, e.g. `Brake` toggled to `Left` means the `Brake` pedal placed at left side, not beside of the `Accelerator` pedal at the right side.
- [ ] If dashboard toggled ON in gyro-mode, drop the steering wheel and show only the horizontal tilt readout at top-center; dashboard shown in remaining space.
- [ ] L/R turn-signal arrows sit above the left pedal (not in the dashboard grid); dashboard grid never shows L/R.

### d. In Rotatable-mode:
- [ ] Steering wheel must be placed in bottom-left corner, with size 50% of the device width resolution.
- [ ] Turn Signals placed above the steering wheel as left/right arrow icons that blink (replaces dashboard-grid L/R, which are removed entirely).
- [ ] Pedal layout (Accelerate and Brake) must placed on bottom-right of the screen, if Clutch pedal turned on, must placed on top-left above the turn signals.
- [ ] If `Gear Up` and `Gear Down` are toggled ON, both must be placed vertically above of the pedals (top-right corner).