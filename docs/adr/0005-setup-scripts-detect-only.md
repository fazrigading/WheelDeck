# Setup scripts detect but don't auto-remediate

Both platform setup scripts detect issues and guide the user to fix them, but neither auto-remediates:

- **Windows** (`check-vigembus.ps1`): Detects missing ViGEmBus and offers to launch the browser to the official release page. The user downloads and runs the installer themselves.
- **Linux** (`install-uinput-rules.sh`): Detects missing uinput rules or SELinux blocks and prints the exact remediation commands. The user runs them manually with `sudo`.

Auto-applying system-level changes (driver installs, SELinux policy modules, udev rules) from a script is a security-sensitive operation that requires conscious user consent. Printing commands or launching a browser keeps the user in control while still reducing friction compared to manual troubleshooting.
