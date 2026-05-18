#!/usr/pkg/bin/bash
# 04-clone-ardupilot.sh
#
# Clone the ArduPilot repo into $ARDUPILOT_DIR and pull all submodules
# (ChibiOS, mavlink, waf, libcanard, ...). Total clone is ~600 MB.

set -euo pipefail

source "$(dirname "$0")/../env.sh"

echo "==> Step 04: clone ArduPilot"

GIT=$LOCALBASE/bin/git

if [[ ! -d "$ARDUPILOT_DIR/.git" ]]; then
    echo "    cloning into $ARDUPILOT_DIR"
    "$GIT" clone --recurse-submodules \
        https://github.com/ArduPilot/ardupilot.git "$ARDUPILOT_DIR"
else
    echo "    repo already present at $ARDUPILOT_DIR"
    cd "$ARDUPILOT_DIR"
    "$GIT" pull --ff-only
    "$GIT" submodule update --init --recursive
fi

# Sanity check: the file ArduPilot expects for board defs must exist.
HWDEF=$ARDUPILOT_DIR/libraries/AP_HAL_ChibiOS/hwdef/MatekH743/hwdef.dat
if [[ ! -f "$HWDEF" ]]; then
    echo "WARNING: $HWDEF missing - submodule init may have failed" >&2
fi

echo "==> Step 04 done. Repo at $ARDUPILOT_DIR"
