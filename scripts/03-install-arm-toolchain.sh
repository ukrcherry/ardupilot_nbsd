#!/usr/pkg/bin/bash
# 03-install-arm-toolchain.sh
#
# Builds gcc-13.2.0 + binutils-2.42 + newlib-4.4.0 for arm-none-eabi
# using a CUSTOM LOCAL pkgsrc package we drop into $PKGSRC_DIR/local/.
#
# Why custom: pkgsrc's cross/arm-none-eabi-gcc is gcc 8.3.0, but ArduPilot
# requires g++ >= 10.2.1 (ChibiOS build error: "ChibiOS build requires
# g++ version 10.2.1 or later, found 5.4.1").
#
# This step takes 30-60 minutes on a 4-core machine - the GCC bootstrap
# is the bulk of it.

set -euo pipefail

source "$(dirname "$0")/../env.sh"

echo "==> Step 03: ARM cross-toolchain (gcc $ARM_GCC_VERSION + binutils $ARM_BINUTILS_VERSION + newlib $ARM_NEWLIB_VERSION)"

# --- Place the overlay package in the pkgsrc tree ------------------------
OVERLAY_SRC="$(cd "$(dirname "$0")/.." && pwd)/pkgsrc-overlay/local/arm-none-eabi-toolchain"
OVERLAY_DST="$PKGSRC_DIR/local/arm-none-eabi-toolchain"

if [[ ! -d "$OVERLAY_SRC" ]]; then
    echo "ERROR: overlay source not found at $OVERLAY_SRC" >&2
    exit 1
fi

echo "    copying overlay package into $OVERLAY_DST"
sudo mkdir -p "$OVERLAY_DST"
sudo cp -R "$OVERLAY_SRC"/. "$OVERLAY_DST"/

# --- Generate distinfo by fetching the upstream tarballs once -----------
# pkgsrc refuses to build without a distinfo file containing checksums
# of every DISTFILE. `make makesum` fetches each DISTFILE and writes the
# checksums for us - this is how a pkgsrc developer normally generates
# distinfo for a new package.
echo "    generating distinfo (fetching upstream tarballs once)"
cd "$OVERLAY_DST"
sudo make distinfo

# Prerequisites for the cross compiler's host-side build.
# Pulled separately so failures are localised.
echo "    installing build prerequisites for gcc bootstrap"
for pkg_path_probe in \
    "devel/bison|bison" \
    "devel/flex|flex" \
    "devel/gmp|gmp" \
    "math/mpfr|mpfr" \
    "math/mpcomplex|mpcomplex" \
    "textproc/gtexinfo|gtexinfo"
do
    path="${pkg_path_probe%|*}"
    probe="${pkg_path_probe#*|}"
    if ! pkg_info -e "${probe}" >/dev/null 2>&1; then
        echo "    [build prereq] $path"
        (cd "$PKGSRC_DIR/$path" && sudo make install clean clean-depends)
    fi
done

# --- Build the toolchain -------------------------------------------------
# This invokes our custom do-build target in the Makefile, which runs
# the four-stage cross-toolchain build.
echo "    starting toolchain build (this takes a while)"
cd "$OVERLAY_DST"
sudo make install
# We intentionally don't `clean` here; if something later complains we want
# the build tree available for diagnosis.

# --- Verify --------------------------------------------------------------
if ! "$ARM_PREFIX/bin/arm-none-eabi-g++" --version >/dev/null 2>&1; then
    echo "ERROR: arm-none-eabi-g++ did not install correctly under $ARM_PREFIX" >&2
    exit 1
fi

GXX_VERSION=$("$ARM_PREFIX/bin/arm-none-eabi-g++" -dumpversion)
echo "    installed arm-none-eabi-g++ version: $GXX_VERSION"

# Sanity-check the ArduPilot minimum.
# Using awk for numeric comparison across major.minor versions.
MIN_OK=$(awk -v v="$GXX_VERSION" 'BEGIN {
    split(v, a, ".");
    if (a[1] > 10 || (a[1] == 10 && a[2] >= 2)) print "yes"; else print "no";
}')
if [[ "$MIN_OK" != "yes" ]]; then
    echo "ERROR: arm-none-eabi-g++ $GXX_VERSION is below the 10.2 minimum required by ArduPilot" >&2
    exit 1
fi

echo "==> Step 03 done. Toolchain installed under $ARM_PREFIX"
