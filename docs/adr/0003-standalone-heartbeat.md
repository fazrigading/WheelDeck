# Heartbeat is a standalone keepalive

The mobile client sends a heartbeat every ~2s as a standalone message. It does not resend the last state.

An earlier implementation resent state alongside each heartbeat as redundancy against packet loss. This was redundant — the desktop already receives state on every sensor/touch update in near-real-time, and the seq field handles ordering. Resending state every 2s wastes bandwidth without meaningful reliability gain.

The heartbeat exists solely to detect dead connections: two missed beats triggers the desktop's neutralize.
