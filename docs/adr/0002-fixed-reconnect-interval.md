# Fixed reconnect interval, not exponential backoff

The mobile client uses a fixed 3-second retry interval when reconnecting after a dropped connection, rather than exponential backoff.

Exponential backoff is the standard pattern for internet-facing services to avoid thundering-herd recovery after an outage. WheelDeck operates on a local network (LAN or USB tethering) with at most a handful of devices. A fixed interval recovers faster from brief Wi-Fi drops, which is the common case — momentary signal fades while moving around a room. Reconnect storms are not a realistic concern at this scale.

If testing reveals reconnect storms in real-world usage (unlikely), this decision should be revisited.
