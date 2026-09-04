# Setup check degrades, doesn't block

The first-run setup check detects whether ViGEmBus (Windows) or uinput permissions (Linux) are configured. When the check fails, the app shows instructions and continues in a degraded state rather than blocking.

A user might want to pair a phone first and install the driver later — pairing doesn't require the virtual controller backend. Hard-blocking would add friction for a step that isn't immediately needed. The desktop can accept and queue pairing requests even before the output backend is ready.

The setup reminder stays visible in the connection UI so the user knows driving won't work until the driver is installed.
