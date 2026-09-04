# Neutralize immediately on active-device switch

When switching the active device from Phone A to Phone B, the desktop immediately zeroes all axes and releases all buttons/keys before B is authorized to send input. This leaves a brief neutral state rather than holding A's last input until B sends its first message.

A future engineer might consider "seamless" handoff — holding A's last state until B sends input — to avoid a momentary gap. We rejected this because the old device may have been disconnected mid-drive with an accelerator pressed, and holding that state for even a fraction of a second is dangerous. Safety over seamlessness.
