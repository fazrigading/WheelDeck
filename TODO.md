# TODO

Remember to update the future plan status to `draft` or `ongoing` or `finished`

## New Issues

### Mobile

Dashboard:

- [ ] Resize gear button size to be 2 rows x 1 cols instead of 2 rows x 2 cols
- [ ] Resize ACC + BRK pedals size to be 4 rows x 1.5 cols instead of 4 rows x 2 cols; we can create it as a one group so it will be 4 rows and 3 cols
- [ ] Create a padding between blocks, except alongside to the screen.
- [ ] Camera Pad keybinds for Up/Down/Left/Right must be set by default alias auto, not manual. Currently it's asking for keybinds after pressing the button in Driving page.
- [ ] When modal of above problem (edit keybinds) pops up, keyboard must afloat, must not resize the whole dashboard.

Controls:
- [ ] "Rotate back to zero" feature in steering wheel is good at lower degrees value, but in higher value, it's still too fast. Create a constant turning back speed, slow and steady.

Settings:
- [ ] Create new page for Keybind Configuration inside Setting page

### Desktop 

Note: this is done on `Linux Fedora 43 7.2.5-100.fc43.x86_64`
1. Steam detected "WheelDeck Virtual Controller" when it's not "Enabled via Steam Input". After enabling the Steam input, it's detected as Xbox 360 Controller.
2. Game detected that hardware name too if not enabled via steam input. But, the game cannot set it neither as steering wheel nor gamepad.
3. Maybe use a fake Hardware ID, like "MOZA TSW Truck Wheel" or "Logitech G923" or something similar (this should correspond to the degrees chosen because each actual wheel sim has different config) to trick the game and Steam and allowing the wheel control.
4. Wheel monitor is working, but the needle is not moving like it supposed to.

---


