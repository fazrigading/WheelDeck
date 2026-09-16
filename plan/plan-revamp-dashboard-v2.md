driving page:
1. remove Top bar "Driving" in the driving mode.
2. change ALL of the dashboard button shape to rectangular (4:3 size), don't use circle shape. Gear buttons must be 3:4, top-arrow & bottom-arrow.
3. steering wheel size is too big and the screen showing bottom overflowed by 64 pixels. maybe it's because anchored incorrectly. the anchor should be at left-bottom corner of the rotatable wheel. and locked to the bottom-left corner of the screen.
4. pedal height is too short! height must be 50% of the screen height (in landscape orientation). and it should anchored at bottom-right corner. the decrease the pading too, it's too wide/far between pedals.
5. the gap between steering whel and pedal should be filled with dashboard items.
6. arrow keys should use `<-` and `->` with straight arrow, not bend arrow.
7. steering wheel "rotates back to zero" is too fast like instant, make it much much slower. also add a toggle ON/OFF on setttings for this "rotates back to zero" feature, so it could manually rotated by user.
8. remove "ACC", "BRK", "CLT" text. change the color of pedal container each to: blue, red, yellow. (respectively, use 25% opacity)
9. turning ON Left turn signal when Right turn signal is also ON should turn off the Right turn signal blinking, vice versa.
10. the pedals "left-right" placement toggle should not enabled in the rotatable mode, but enabled in gyro mode.
11. in the rotatable mode, the pedals toggle "ON/OFF" only belongs to Clutch pedal, the Acceleration and Brake must ON.
12. the order of pedals in rotatable mode is incorrect, Acceleration pedal must be on the right-most, not Clutch pedal.
13. Wheel arc axis red bar must start from 0 not -1 to +1.
14. Back navigation button from the phone should ask confirmation of exiting the driving mode (android modal popup). there should appear three options: Settings, Disconnect, and Stay. Disconnect should navigate to the app Home, not exiting the app.

---

i have an idea for the driving layout on rotatable mode:
- Divide screen area by 2 rows x 3 columns, let's name the block A B C on 1st row, and D E F on 2nd row.
- sidenote: i will replace every buttons text into proper icon, once we are set with the placement.
- each block has 4 rows x 5 columns, let's call it cell:
  - [G H I J K]
  - [L M N O P]
  - [Q R S T U]
  - [V W X Y Z]
- wheel = 4w x 4h
  - [G-H-I-J, L-M-N-O, Q-R-S-T, V-W-X-Y]
- pedal (each) = 2w x 4h
  - [J-K, O-P, T-U, Y-Z] = Accelerator
  - [H-I, M-N, R-S, W-X] = Brake
- camera analog = 3w x 3h
  - [I-J-K, N-O-P, S-T-U]
- gear (each) = 1w x 2h
  - [G-H, L-M] = Gear Up
  - [Q-R, V-W] = Gear Down
- buttons = 1w x 1h
  - [Z]

H-Shifter preset by Developer:
```text
* = No default gamepad keybind for this in-game

Block A [1,1]:
- [J-K, O-P, T-U, Y-Z] = Clutch Pedal 
- [G] = Adaptive Cruise Control <LB + Button B (Hold)> (Note: Pressing brake won't toggle OFF the visual button)
- [H] = Lane Keeping Assistant <LB + DPadUp> 
- [I] = Lane Assistant Mode <LB + DPadUp (Hold)>
- [L] = Lift/Drop Trailer Axle <None> (*; will use `T`)
- [M] = Lift/Drop Truck Axle <U> (*)
- [N] = Trailer Attach/Detach <DPadLeft (Hold)>
- [Q] = Hazard Warning <Button Select (Hold)> (note: red-triangle icon)
- [R] = Beacon <LB + Button X> (note: patrol light icon)
- [S] = Differential Lock <LB + DPadRight>
- [V] = Left Signal <DPadLeft>
- [W] = Right Signal <DPadRight>
- [X] = High Beam <Button X (Hold)>

Block B [1,2]:
- 1st row: Audio Player (use symbols):
  - [G] = Vol- <None> (*; will use `L`)
  - [H] = Prev <None> (*; will use `J`)
  - [I] = Play/Pause <None> (*; will use `K`)
  - [J] = Next <None> (*; will use `U`)
  - [K] = Vol+ <None> (*; will use `O`)
- 2nd row:
  - [L] = Driver Window Up <None> (*; will use `RightShift`)
  - [M] = Navigation Zoom In <None> (*; will use `Slash`) 
  - [N] = Cruise Control Speed Increase <LB + Y>
  - [O] = Retarder Increase <Semicolon>
  - [P] = Passenger Window Up <Comma>
- 3rd row: 
  - [Q] = Driver Window Down <None> (*; will use `RightCtrl`)
  - [R] = Navigation Zoom Out <Button Y> 
  - [S] = Cruise Control Speed Decrease <LB + A>
  - [T] = Retarder Decrease <Quote>
  - [U] = Passenger Window Down <Dot>
- 4th row: 
  - [V] = Overlay Activation <Tab>
  - [W] = Chat Activation <Y>
  - [X] = Quick Replies <Q>
  - [Y] = Show Name Tags <Z>
  - [Z] = Push to Talk <X>

Block C [1,3]:
- [G-H, L-M] = Gear Up <LB + R-Analog Up>
- [Q-R, V-W] = Gear Down <LB + R-Analog Down>
- [I-J-K, N-O-P, S-T-U] = Analog stick for interior camera
  Note:
  - Right Stick Analog from Virtual Controller; if not possible to be implemented, use Numpad keybinds
  - Zoom Interior Camera <RS> (Double-tapping the analog)
- [X] = Emergency Brake <LB + DPadDown>
- [Y] = Engine Brake <B> (*)
- [Z] = Cruise Control <Button B (Hold)> (Note: Disengages the moment user touch the brake, so it must visually toggled to OFF when that happens)

Block D [2,1]: 
- [G-H-I-J, L-M-N-O, Q-R-S-T, V-W-X-Y] = Steering wheel
- [K] = Horn <LS>
- [P] = Flasher (Air Horn) <LB + LS>
- [U] = Wiper <DPadDown>
- [Z] = Light Modes <Button X>

Block E [2,2]:
- 1st row:
  - [G] = Interior camera <Digit1>
  - [H] = Chasing camera <Digit2>
  - [I] = Top-down camera <Digit3>
  - [J] = Roof camera <Digit4>
  - [K] = Lean-out camera <Digit5>
- 2nd row:
  - [L] = Quick Save <F8>
  - [M] = Dashboard Info <I>
  - [N] = Next Camera <Digit9>
  - [O] = HUD Widget <F3>
  - [P] = Cruise Control Resume <LB + B>
- 3rd row: 
  - [Q] = Quick Info <Button Start (Hold)> 
  - [R] = Mirror Toggle <F2>
  - [S] = Screenshot <F10> 
  - [T] = Widget Options <F6>
  - [U] = Services & Adjustments <F7>
- 4th row: 
  - [V] = Menu <Button Start>
  - [W] = World Map <Button Select>
  - [X] = Photo Mode <LB + DPadLeft>
  - [Y] = Garage Manager <G>
  - [Z] = Activate <Button A>

Block F [2,3]:
- [G] = Engine Start Electricity <None> (*; will use `R`)
- [L] = Engine Start <DPadRight (Hold)>
- [Q] = Parking Brake <DPadDown (Hold)> 
- [V] = Shift to Neutral <LB + RS (Hold)>
- [H-I, M-N, R-S, W-X] = Brake
- [J-K, O-P, T-U, Y-Z] = Accelerator

```

---

another idea coming from button layout problem above:
1. can we create a user customisable button layout feature in flutter? user can set/move each buttons to desired position in the layout
2. if we can't do that in flutter, which programming language can we use to achieve that? 
3. can we also modify/arrange the proposed custom button layout on desktop-side that sync with mobile-side?
