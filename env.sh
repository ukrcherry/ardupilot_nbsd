# env.sh - shared environment for all install scripts.
# Sourced by every numbered script. POSIX sh compatible.

# Where pkgsrc tree lives. NetBSD convention.
PKGSRC_DIR=${PKGSRC_DIR:-/usr/pkgsrc}

# Where pkgsrc installs things. NetBSD default.
LOCALBASE=${LOCALBASE:-/usr/pkg}

# pkgsrc branch, used directly as the URL path component on
# cdn.NetBSD.org/pub/pkgsrc/<branch>/pkgsrc.tar.gz.
#   pkgsrc-2026Q1, pkgsrc-2025Q4, pkgsrc-2025Q3, ...  quarterly stable
#   current                                            rolling dev (~weekly tarball)
# 2026Q1 is the latest quarterly as of May 2026; "current" gets you the newest
# versions of everything but breaks more often.
PKGSRC_BRANCH=${PKGSRC_BRANCH:-pkgsrc-2026Q1}

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

# NetBSD release & arch - used to fetch missing distribution sets (comp.tgz
# etc.) from the CDN if the system was installed without them. Auto-detected
# from uname; override if you're cross-installing or building on a snapshot.
NETBSD_RELEASE=${NETBSD_RELEASE:-$(uname -r)}
NETBSD_ARCH=${NETBSD_ARCH:-$(uname -m)}
NETBSD_SETS_URL=${NETBSD_SETS_URL:-https://cdn.NetBSD.org/pub/NetBSD/NetBSD-${NETBSD_RELEASE}/${NETBSD_ARCH}/binary/sets}

# Make sure pkgsrc-installed binaries are on PATH for every script.
# /usr/pkg/bin is where bash, git, python3, etc. land.
PATH=$LOCALBASE/sbin:$LOCALBASE/bin:$ARM_PREFIX/bin:$PATH
export PATH

# Make pkgsrc fetches retry on flaky networks - large GCC tarball can fail.
FETCH_CMD="ftp -V -o"
export FETCH_CMD

# Don't echo every command; individual scripts set -x if they want.
umask 022
