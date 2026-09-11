# TODO — Mobile & Desktop UI Revamp

Remember to update the corresponding plan status: `draft`/`ongoing`/`finished`

## branch: feature/rotatable-steering-mode

> Detailed plan: To be added

### desktop

- [ ] The virtual steering wheel should have two options: gyro or rotateable.
- [ ] For ETS2, rotateable is the default option, with 900 degrees. 
- [ ] add function for 180 degrees, 270 degrees, 1080 degrees, 1800 degrees, and 2520 degrees.

### mobile

- [ ] Change the `controller type` options to toggle (ON/OFF) for Acceleration, Brake, Clutch, and Dashboard (except Steering Wheel).
- [ ] Steering Wheel has a toggle for `Rotateable or Gyro`, this will be functional after 
- [ ] Change the `Pedal layout` options to a `Left or Right` toggle that will shown on the card if turned to ON, otherwise disabled.
- [ ] In Gyro-mode: 
  - [ ] Steering wheel should shown in the middle with indicator of X-axis line under it. 
  - [ ] Selected pedal layout option should put each pedal in its preferred location, e.g. `Brake` toggled to `Left` means the `Brake` pedal placed at left side, not beside of the `Accelerator` pedal at the right side.
  - [ ] If dashboard toggled ON, the gyro steering wheel indicator must be small, shown at middle top, above of the dashboard buttons.

---

### branch `feature/revamp-dashboard` :
- [ ] Light modes actually has 2 modes (Parking Lights & Low Beam), so toggling it would change the the text and the button visually
- [ ] Blinking button for Left-Right Turn Signal
- Fix existing buttons:
  - [ ] Decrease the size of all dashboard buttons.
  - [ ] Change "Cruise Toggle" keybind to `C`
  - [ ] Change "Cruise set/resume" to "Cruise Resume", keybind is set-able 
  - [ ] Change "HI" button name to "High-beam" keybind to `K`
- New Buttons:
  - [ ] "Hazard Lights" (`F`)
  - [ ] "Warning / Beacon Lights" (`O`)
  - [ ] "Light Horn / Flasher" (`J`)
  - [ ] "Horn" on the center of Steering Wheel (`H`)
  - [ ] "Trailer" (`T`) 
  - [ ] "Gear Up" (`Left Shift`)
  - [ ] "Gear Down" (`Left Ctrl`)
  - [ ] "Lift / Drop Axle" (`U`)
  - [ ] "Camera View" (`9`)
- Add additional settings section:
  - [ ] Create option for "Engine Start" button on dashboard can be hold or just press, also make it visually toggled ON in both option. The toggle should follow the M3 design guideline.
  - Create toggle for these buttons:
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
    - [ ] Radio Player (`R`)
    - Set-able keybinds by user (default to empty keybinds):
      - [ ] Start/Stop Engine Electricity
      - [ ] Wipers Back
      - [ ] Adaptive Cruise Control Mode
      - [ ] Cruise Control Speed Increase
      - [ ] Cruise Control Speed Decrease
      - [ ] Lane Assistant Mode
      - [ ] Lane Keeping Assistant
      - [ ] Emergency Brake
