#!/usr/bin/env bash
# WheelDeck Linux setup check — detects uinput access issues and prints
# remediation commands. Does NOT auto-apply changes (per ADR-0005).

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

pass() { printf "${GREEN}✓${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}!${NC} %s\n" "$1"; }
fail() { printf "${RED}✗${NC} %s\n" "$1"; }

issues=0

echo "WheelDeck uinput setup check"
echo "============================"
echo

# 1. Check if uinput device exists
UINPUT_PATH=""
if [ -e /dev/uinput ]; then
    UINPUT_PATH="/dev/uinput"
elif [ -e /dev/input/uinput ]; then
    UINPUT_PATH="/dev/input/uinput"
fi

if [ -z "$UINPUT_PATH" ]; then
    fail "uinput device not found (/dev/uinput or /dev/input/uinput)"
    echo "  Install the uinput module:"
    echo "    sudo modprobe uinput"
    echo
    issues=$((issues + 1))
else
    pass "uinput device found at $UINPUT_PATH"
fi

# 2. Check if current user can write to uinput
if [ -n "$UINPUT_PATH" ]; then
    if [ -w "$UINPUT_PATH" ]; then
        pass "Current user can write to $UINPUT_PATH"
    else
        fail "No write access to $UINPUT_PATH"
        if ! getent group input >/dev/null 2>&1; then
            echo "  Create the input group and add yourself:"
            echo "    sudo groupadd -f input"
            echo "    sudo usermod -aG input \$USER"
        else
            echo "  Add yourself to the input group:"
            echo "    sudo usermod -aG input \$USER"
        fi
        echo "  Then log out and back in for group changes to take effect."
        echo
        issues=$((issues + 1))
    fi
fi

# 3. Check if user is in the input group
if groups "$USER" 2>/dev/null | grep -qw input; then
    pass "User is in the input group"
else
    warn "User is not in the input group"
    if ! getent group input >/dev/null 2>&1; then
        echo "  Create the input group and add yourself:"
        echo "    sudo groupadd -f input"
        echo "    sudo usermod -aG input \$USER"
    else
        echo "  Add yourself to the input group:"
        echo "    sudo usermod -aG input \$USER"
    fi
    echo "  Then log out and back in for group changes to take effect."
    echo
    issues=$((issues + 1))
fi

# 4. Check SELinux (Fedora / RHEL / CentOS)
if command -v getenforce >/dev/null 2>&1; then
    SELINUX_MODE=$(getenforce 2>/dev/null || echo "Disabled")
    if [ "$SELINUX_MODE" = "Enforcing" ]; then
        if command -v ausearch >/dev/null 2>&1; then
            DENIALS=$(ausearch -m avc -ts recent 2>/dev/null | grep -c "uinput" || true)
            if [ "$DENIALS" -gt 0 ]; then
                fail "SELinux is blocking uinput ($DENIALS recent denials)"
                echo "  Temporary test (reboot-safe):"
                echo "    sudo setenforce 0"
                echo "  Permanent fix — create a policy module:"
                echo "    cat > /tmp/wheeldeck_uinput.te <<'EOF'"
                echo "    module wheeldeck_uinput 1.0;"
                echo "    require { type input_event_t; }"
                echo "    allow unconfined_t input_event_t:chr_file { open write ioctl };"
                echo "    EOF"
                echo "    sudo checkmodule -M -m -o /tmp/wheeldeck_uinput.mod /tmp/wheeldeck_uinput.te"
                echo "    sudo semodule_package -o /tmp/wheeldeck_uinput.pp -m /tmp/wheeldeck_uinput.mod"
                echo "    sudo semodule -i /tmp/wheeldeck_uinput.pp"
                echo
                issues=$((issues + 1))
            else
                pass "SELinux enforcing, no uinput denials detected"
            fi
        else
            warn "SELinux enforcing but ausearch not found — cannot check for denials"
            echo "  If uinput fails, try: sudo setenforce 0"
            echo
        fi
    else
        pass "SELinux is not enforcing ($SELINUX_MODE)"
    fi
else
    pass "SELinux not present (not Fedora/RHEL)"
fi

# 5. Check if uinput module is loaded
if lsmod 2>/dev/null | grep -q uinput; then
    pass "uinput kernel module is loaded"
else
    warn "uinput kernel module may not be loaded"
    echo "  Load it with:"
    echo "    sudo modprobe uinput"
    echo "  To load on boot:"
    echo "    echo uinput | sudo tee /etc/modules-load.d/uinput.conf"
    echo
    issues=$((issues + 1))
fi

# Summary
echo "============================"
if [ "$issues" -eq 0 ]; then
    echo "All checks passed. uinput is ready for WheelDeck."
    exit 0
else
    echo "$issues issue(s) found. Run the suggested commands above, then re-run this script."
    exit 1
fi
