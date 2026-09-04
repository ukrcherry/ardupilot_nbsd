#!/usr/bin/env bash
# stage1-build-payload.sh - runs on NetBSD 11 with our earlier scripts applied.
#
# Produces $HERE/payload.tar.xz containing:
#   pkg-cache/     one .tgz per installed pkgsrc pkg we need
#   ardupilot/     the built ArduPilot tree (with build/ artifacts)
#   postinstall.sh script that runs pkg_add on everything after sysinst

set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)

# --- Sanity check: this script MUST run on NetBSD ------------------------
# It calls pkg_tarup(1) to re-tar installed pkgsrc packages, reads
# /usr/pkgsrc, and expects $HOME/ardupilot to exist (put there by
# install-all.sh from the parent repo). None of that works on Linux.
if [ "$(uname -s)" != "NetBSD" ]; then
    cat <<EOF >&2
ERROR: stage1 must run on a NetBSD host.

Current host: $(uname -sr)

This script uses NetBSD-only tools (pkg_tarup, pkg_info) and expects
the ArduPilot environment produced by ../ardupilot-netbsd-pkgsrc/install-all.sh
to be present at:
    /usr/pkgsrc                (pkgsrc tree)
    /usr/pkg                   (installed pkgs)
    \$HOME/ardupilot           (built ArduPilot repo)

Run stage2 instead if all you want is to splice an existing payload
into a base ISO - stage2 is portable and works on Linux with xorriso.
EOF
    exit 1
fi

PAYLOAD=$HERE/payload
ARDUPILOT_DIR=${ARDUPILOT_DIR:-$HOME/ardupilot}
LOCALBASE=${LOCALBASE:-/usr/pkg}

# pkg_tarup(1) turns an installed pkg back into an installable .tgz.
# ../../pkgtools/pkg_tarup in pkgsrc; build it if missing.
if ! command -v pkg_tarup >/dev/null 2>&1; then
    (cd /usr/pkgsrc/pkgtools/pkg_tarup && sudo make install clean clean-depends)
fi

# The set of pkgs we ship. Match what our install-all.sh installed.
# ArduPilot only needs runtime dependents at target-boot time (git, python,
# arm cross toolchain, etc). Everything else is pulled by pkg_add's deps.
PKGS=(
    bash gmake gawk ccache git-base wget pkgconf libtool
    zlib libxml2 libxslt
    python312 py312-pip py312-setuptools py312-wheel
    py312-numpy py312-lxml
    cross-arm-none-eabi-toolchain      # our custom local pkg from step 03
)

echo "==> stage 1: packaging installed pkgsrc pkgs into $PAYLOAD/pkg-cache"
rm -rf "$PAYLOAD"
mkdir -p "$PAYLOAD/pkg-cache"

for p in "${PKGS[@]}"; do
    # Resolve exact installed version - pkg_tarup wants the full name.
    full=$(pkg_info -e "$p" && pkg_info | awk -v p="$p" '$1 ~ "^"p {print $1; exit}')
    if [ -z "$full" ]; then
        echo "  [skip] $p (not installed - was it in your install-all.sh run?)"
        continue
    fi
    echo "  [pack] $full"
    (cd "$PAYLOAD/pkg-cache" && sudo pkg_tarup "$full")
done

# --- ArduPilot: ship the tree with build artifacts already present -----
if [ -d "$ARDUPILOT_DIR" ]; then
    echo "==> stage 1: bundling $ARDUPILOT_DIR"
    # Exclude .git objects to keep size sane (~600 MB -> ~200 MB).
    tar -C "$(dirname "$ARDUPILOT_DIR")" \
        --exclude='ardupilot/.git' \
        -cJf "$PAYLOAD/ardupilot.tar.xz" \
        "$(basename "$ARDUPILOT_DIR")"
fi

# --- Postinstall script (goes onto the ISO) -----------------------------
cp "$HERE/payload-template/postinstall.sh" "$PAYLOAD/postinstall.sh"
chmod +x "$PAYLOAD/postinstall.sh"

# --- Final tarball ------------------------------------------------------
echo "==> stage 1: tarring payload"
tar -C "$HERE" -cJf "$HERE/payload.tar.xz" payload
du -h "$HERE/payload.tar.xz"
echo "==> stage 1 done: $HERE/payload.tar.xz"
