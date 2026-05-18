#!/usr/pkg/bin/bash
# 02-install-python-deps.sh
#
# 1. Build python 3.12 from pkgsrc source.
# 2. Build the few Python modules that have C extensions also via pkgsrc
#    (numpy, lxml) - faster and avoids needing every C dev header from pip.
# 3. Create a venv at $AP_VENV and pip-install pure-Python ArduPilot
#    runtime deps into it. pip downloads SDISTs and builds them locally,
#    which is still "from source" - no wheels are used.
#
# Why a venv at all? On modern Linux/BSD pip refuses to install to the
# system site-packages by default (PEP 668). A venv sidesteps that and
# keeps the toolchain hermetic.

set -euo pipefail

source "$(dirname "$0")/../env.sh"

echo "==> Step 02: Python interpreter + ArduPilot's Python deps"

pkg_build() {
    local path="$1" probe="$2"
    if pkg_info -e "${probe}" >/dev/null 2>&1; then
        echo "    [skip] $path"; return 0
    fi
    echo "    [build] $path"
    cd "$PKGSRC_DIR/$path"
    sudo make install clean clean-depends
}

# --- Python interpreter via pkgsrc --------------------------------------
# lang/python312 gives /usr/pkg/bin/python3.12. There's also a symlink
# package, lang/python-tools, that drops a generic /usr/pkg/bin/python3.
pkg_build lang/python312            python312
pkg_build lang/py-pip               py312-pip
pkg_build devel/py-setuptools       py312-setuptools
pkg_build devel/py-wheel            py312-wheel

# C-extension Python modules: building these via pkgsrc is much faster
# than letting pip compile them, because pkgsrc has the C deps wired up
# correctly (BLAS for numpy, libxml2 for lxml, etc.).
pkg_build math/py-numpy             py312-numpy
pkg_build textproc/py-lxml          py312-lxml

# --- ArduPilot virtualenv -------------------------------------------------
# All pure-Python deps go into a venv so we don't pollute the system.
PY=$LOCALBASE/bin/python3.12
if [ ! -d "$AP_VENV" ]; then
    echo "    creating venv at $AP_VENV"
    # --system-site-packages so the venv can see pkgsrc's numpy/lxml.
    "$PY" -m venv --system-site-packages "$AP_VENV"
fi

# Activate the venv for the rest of this script.
# shellcheck disable=SC1091
source "$AP_VENV/bin/activate"

# Make sure pip itself is up to date - older pip can't resolve modern
# sdist-only packages cleanly.
pip install --upgrade pip setuptools wheel

# --- ArduPilot Python packages -------------------------------------------
# These mirror the ones in install-prereqs-arch.sh / install-prereqs-ubuntu.sh,
# minus the GUI things (pygame, wxpython, opencv) which only matter for
# MAVProxy's map UI and SITL animation - neither of which is needed to
# satisfy the user's `./waf copter` goal.
#
# CRITICAL PIN: empy==3.3.4. ArduPilot's chibios_hwdef.py uses the pre-4.x
# empy API (em.RAW_OPT, em.BUFFERED_OPT). empy 4.x rewrote that API and
# breaks the build. See https://github.com/PX4/PX4-Autopilot/issues/22515.
pip install --no-binary=:all: \
    'empy==3.3.4' \
    'future'      \
    'pymavlink'   \
    'pexpect'     \
    'intelhex'    \
    'dronecan'    \
    'pyserial'    \
    'pyparsing'   \
    'psutil'

# --no-binary=:all: forces pip to build everything from sdist, satisfying
# the "compile from source" requirement.

# Hint for the user's shell - we'll print this at the end of install-all.sh.
echo "==> Step 02 done. Activate the venv with:"
echo "        source $AP_VENV/bin/activate"
