# env.sh - shared environment for all install scripts.
# Sourced by every numbered script. POSIX sh compatible.

# Where pkgsrc tree lives. NetBSD convention.
PKGSRC_DIR=${PKGSRC_DIR:-/usr/pkgsrc}

# Where pkgsrc installs things. NetBSD default.
LOCALBASE=${LOCALBASE:-/usr/pkg}

# pkgsrc branch (quarterly stable). Adjust if you want -current.
# 2025Q1 is broadly compatible with NetBSD 11.0_RC4.
PKGSRC_BRANCH=${PKGSRC_BRANCH:-pkgsrc-2025Q3}

# Where we clone ArduPilot.
ARDUPILOT_DIR=${ARDUPILOT_DIR:-$HOME/ardupilot}

# Where the Python venv for ArduPilot's pip deps lives.
AP_VENV=${AP_VENV:-$HOME/ardupilot-venv}

# Versions for the locally-built ARM cross-toolchain.
# pkgsrc's cross/arm-none-eabi-gcc is stuck at 8.3.0; ArduPilot needs >=10.2.1.
ARM_BINUTILS_VERSION=2.42
ARM_GCC_VERSION=13.2.0
ARM_NEWLIB_VERSION=4.4.0.20231231

# Where the cross-toolchain ends up (inside pkgsrc LOCALBASE).
ARM_PREFIX=$LOCALBASE/cross/arm-none-eabi

# Make sure pkgsrc-installed binaries are on PATH for every script.
# /usr/pkg/bin is where bash, git, python3, etc. land.
PATH=$LOCALBASE/sbin:$LOCALBASE/bin:$ARM_PREFIX/bin:$PATH
export PATH

# Make pkgsrc fetches retry on flaky networks - large GCC tarball can fail.
FETCH_CMD="ftp -V -o"
export FETCH_CMD

# Don't echo every command; individual scripts set -x if they want.
umask 022
