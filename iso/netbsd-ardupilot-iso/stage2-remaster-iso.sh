#!/usr/bin/env bash
# stage2-remaster-iso.sh - take base NetBSD ISO + payload.tar.xz -> custom ISO.
#
# Uses xorriso in "replay boot" mode so El Torito boot info from the input
# ISO is preserved exactly. Adds our payload under /ardupilot/ on the ISO.

set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)

BASE_ISO=${1:?base NetBSD ISO path required}
OUT_ISO=${2:?output ISO path required}
PAYLOAD=${PAYLOAD:-$HERE/payload.tar.xz}

command -v xorriso >/dev/null || {
    echo "ERROR: xorriso not found. Install: xbps-install xorriso  /  pkgin install xorriso  /  apt install xorriso" >&2
    exit 1
}
[ -f "$BASE_ISO" ] || { echo "ERROR: $BASE_ISO not found" >&2; exit 1; }
[ -f "$PAYLOAD"  ] || { echo "ERROR: $PAYLOAD not found - run stage1 first" >&2; exit 1; }

# Stage the payload under a working dir so xorriso -map can add it.
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
tar -C "$STAGE" -xJf "$PAYLOAD"    # extracts as $STAGE/payload/{pkg-cache,ardupilot.tar.xz,postinstall.sh}

echo "==> stage 2: remastering $BASE_ISO -> $OUT_ISO"
# -indev/-outdev + `boot_image any replay` copies boot metadata verbatim.
# -map <local> <iso_path> adds files to a specific location in the ISO tree.
xorriso \
    -indev  "$BASE_ISO" \
    -outdev "$OUT_ISO"  \
    -boot_image any replay \
    -map "$STAGE/payload" /ardupilot \
    -end

ls -lh "$OUT_ISO"
echo "==> stage 2 done. Boot the ISO, run sysinst as normal, then:"
echo "        mount_cd9660 /dev/cd0a /mnt && sh /mnt/ardupilot/postinstall.sh"
