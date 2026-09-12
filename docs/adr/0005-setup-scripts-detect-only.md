# Setup scripts detect but don't auto-remediate

The Linux setup script detects issues and guides the user to fix them, but does not auto-remediate:

- **Windows** (`check-hidmaestro.ps1`): Reports HIDMaestro driver status. Install itself is automatic via the app (`HMContext.InstallDriver()`, admin required), so the script is a status check. This supersedes the original detect-only rule on Windows.
- **Linux** (`install-uinput-rules.sh`): Detects missing uinput rules or SELinux blocks and prints the exact remediation commands. The user runs them manually with `sudo`.

Auto-applying system-level changes (driver installs, SELinux policy modules, udev rules) from a script is a security-sensitive operation that requires conscious user consent. Printing commands or launching a browser keeps the user in control while still reducing friction compared to manual troubleshooting.
