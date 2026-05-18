#!/bin/sh
# install-all.sh - master orchestrator.
#
# POSIX sh, because on a fresh NetBSD the very first step has to bootstrap
# bash. After step 00 we re-exec ourselves under bash so the rest can use
# bash-isms.

set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"

# 1. Bootstrap pkgsrc + bash. Runs in /bin/sh.
echo "================================================================"
echo " ardupilot-netbsd-pkgsrc: installer"
echo "================================================================"
sh ./scripts/00-bootstrap-pkgsrc.sh

# After step 00, bash is available at /usr/pkg/bin/bash.
BASH=/usr/pkg/bin/bash
if [ ! -x "$BASH" ]; then
    echo "Step 00 finished but $BASH is not executable - aborting." >&2
    exit 1
fi

# 2. Each subsequent step in bash, in order. If one fails the master stops -
#    re-run that script directly after fixing.
for step in 01-install-base.sh \
            02-install-python-deps.sh \
            03-install-arm-toolchain.sh \
            04-clone-ardupilot.sh \
            05-build-test.sh
do
    echo "================================================================"
    echo " running $step"
    echo "================================================================"
    "$BASH" "./scripts/$step"
done

echo
echo "================================================================"
echo " all steps complete."
echo "================================================================"
echo
echo " To use ArduPilot in a new shell:"
echo "     export PATH=/usr/pkg/cross/arm-none-eabi/bin:/usr/pkg/bin:\$PATH"
echo "     . \$HOME/ardupilot-venv/bin/activate"
echo "     cd \$HOME/ardupilot"
echo "     ./waf configure --board MatekH743"
echo "     ./waf copter"
