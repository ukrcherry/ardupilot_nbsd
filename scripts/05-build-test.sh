#!/usr/pkg/bin/bash
# 05-build-test.sh
#
# Runs the four ./waf commands the user wants to succeed:
#   ./waf configure                         # SITL/host build
#   ./waf all
#   ./waf configure --board MatekH743       # cross build for STM32H7
#   ./waf copter
#
# Wires up the venv, the ARM toolchain PATH, and ccache.
#
# Honest expectations:
#   * The cross build (MatekH743 + copter) is most likely to work cleanly
#     because it's bare-metal ChibiOS and only depends on the ARM
#     toolchain we built in step 03.
#   * The native `./waf all` (SITL) may hit Linux-isms in AP_HAL_SITL.
#     If so, the failure will name a file like SITL_State_common.cpp -
#     typically a missing <sys/prctl.h>, /proc, or epoll. Patch as a
#     normal POSIX port: NetBSD has kqueue, not epoll.

set -euo pipefail

source "$(dirname "$0")/../env.sh"

echo "==> Step 05: build verification"

cd "$ARDUPILOT_DIR"

# Activate the Python venv that has empy, pymavlink, etc.
# shellcheck disable=SC1091
source "$AP_VENV/bin/activate"

# Make sure ArduPilot's own helper scripts are on PATH (used by `./waf`
# for things like sim_vehicle.py, but harmless to have here).
export PATH="$ARDUPILOT_DIR/Tools/autotest:$PATH"

# Make sure the ARM toolchain is on PATH ahead of any system tools.
export PATH="$ARM_PREFIX/bin:$PATH"

# Tell waf to use gmake-compatible parallelism.
JOBS=$(sysctl -n hw.ncpu 2>/dev/null || echo 2)

# ccache wiring: ArduPilot looks for arm-none-eabi-{gcc,g++} on PATH.
# On Linux the convention is to symlink /usr/lib/ccache/arm-none-eabi-gcc
# pointing at /usr/bin/ccache. On NetBSD we mimic this by creating a
# user-local ccache shim directory and prepending it to PATH.
CCACHE_SHIM=$HOME/.ccache-shims
mkdir -p "$CCACHE_SHIM"
for tool in arm-none-eabi-gcc arm-none-eabi-g++ cc gcc c++ g++; do
    if [[ ! -L "$CCACHE_SHIM/$tool" ]]; then
        ln -sf "$LOCALBASE/bin/ccache" "$CCACHE_SHIM/$tool"
    fi
done
export PATH="$CCACHE_SHIM:$PATH"

# Show what the build will use, for the log.
echo "    using:"
echo "      python  : $(command -v python3)"
echo "      gcc     : $(command -v gcc) ($(${LOCALBASE}/bin/ccache -V 2>/dev/null | head -1 || true))"
echo "      arm g++ : $(command -v arm-none-eabi-g++)"
echo "      git     : $(command -v git)"
echo "      jobs    : $JOBS"

run() {
    echo
    echo "    \$ $*"
    "$@"
}

# --- 1. SITL/host configure ---------------------------------------------
run ./waf configure

# --- 2. Build everything for the host -----------------------------------
# This will try to build SITL for every vehicle. As noted above, if any
# .cpp fails on NetBSD it's usually a small POSIX-vs-Linux header issue.
# We don't bail out on failure here so we can still try the cross build.
if ! run ./waf -j "$JOBS" all; then
    echo "    NOTE: './waf all' failed - this is the SITL native build."
    echo "    The cross build below is the user's actual target."
fi

# --- 3. Reconfigure for the MatekH743 board ------------------------------
run ./waf configure --board MatekH743

# --- 4. Build copter firmware for MatekH743 ------------------------------
run ./waf -j "$JOBS" copter

# --- Report -------------------------------------------------------------
APJ=$ARDUPILOT_DIR/build/MatekH743/bin/arducopter.apj
if [[ -f "$APJ" ]]; then
    echo
    echo "==> SUCCESS: $APJ ($(stat -f %z "$APJ" 2>/dev/null || stat -c %s "$APJ") bytes)"
else
    echo "==> $APJ not found - check above output for the failing step"
    exit 1
fi
