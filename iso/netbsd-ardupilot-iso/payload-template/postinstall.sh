#!/bin/sh
# postinstall.sh - run after sysinst finishes and the target system is booted.
#
# Invocation on the fresh install:
#     mount_cd9660 /dev/cd0a /mnt
#     sh /mnt/ardupilot/postinstall.sh
#
# pkg_adds every cached pkg, then unpacks ArduPilot into /home/ardupilot.

set -eu
HERE=$(cd "$(dirname "$0")" && pwd)   # /mnt/ardupilot when run from the CD
PKG_CACHE=$HERE/pkg-cache
AP_TARBALL=$HERE/ardupilot.tar.xz

echo "==> installing pkgsrc pkgs from $PKG_CACHE"
# pkg_add -U updates in place; -f overrides "different version" refusal
# (see FINDINGS.txt Finding 5). Loop so dependency order doesn't matter -
# pkg_add prints deps it can't find; the second pass picks them up.
for pass in 1 2; do
    for tgz in "$PKG_CACHE"/*.tgz; do
        pkg_add -U -f "$tgz" 2>/dev/null || true
    done
done

# Verify our critical bits landed.
for probe in bash git python3.12 arm-none-eabi-g++; do
    if ! command -v "$probe" >/dev/null; then
        echo "WARNING: $probe not on PATH after pkg_add" >&2
    fi
done

# --- ArduPilot tree -----------------------------------------------------
if [ -f "$AP_TARBALL" ]; then
    echo "==> unpacking ArduPilot into /home/ardupilot"
    mkdir -p /home
    tar -C /home -xJf "$AP_TARBALL"
    mv /home/ardupilot* /home/ardupilot 2>/dev/null || true
fi

# NetBSD's dialer group is what /dev/tty* is in - Linux calls it dialout.
# Add the first non-root user to it so they can talk to a flight controller.
first_user=$(awk -F: '$3>=1000 && $3<60000{print $1; exit}' /etc/passwd || true)
if [ -n "${first_user:-}" ]; then
    usermod -G dialer "$first_user" 2>/dev/null || true
fi

cat <<EOF

==> ArduPilot ready.
    To build for MatekH743:
        export PATH=/usr/pkg/cross/arm-none-eabi/bin:/usr/pkg/bin:\$PATH
        cd /home/ardupilot
        ./waf configure --board MatekH743
        ./waf copter
EOF
