# Camera pad input modes are encoded in the wire identifiers

The camera pad's numpad and arrow modes send different desktop keys for the same
physical direction, and the desktop resolves keys from control identifiers only
(`RouteKey` ignores phone key strings). The mode is therefore encoded in the
identifiers themselves: thirteen controls — the nine-entry numpad set
(`camera_pad_up` through `camera_pad_recenter`) plus `camera_pad_arrow_up`,
`camera_pad_arrow_down`, `camera_pad_arrow_left`, and `camera_pad_arrow_right`.
Arrow diagonals have no identifiers because they are disabled in arrow mode.

**Considered options**: a key-hint field on the button message (rejected:
`ButtonMessage` carries no key field and `RouteKey` deliberately ignores
phone-supplied keys — adding one creates a second resolution path); desktop-side
pad mode state switched by a control event (rejected: a new state machine on the
desktop and a drift risk against the phone's mode). Consequence: future camera
control types (Simple, Analog) add their own identifier sets under the same
pattern.
