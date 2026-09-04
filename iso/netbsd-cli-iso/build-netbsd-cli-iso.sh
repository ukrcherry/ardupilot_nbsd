#!/usr/bin/env bash
# build-netbsd-cli-iso.sh - vanilla CLI NetBSD 11.0 install ISO, no ArduPilot.
#
# NetBSD's install ISO is already CLI-only - sysinst is a curses installer,
# there is no GUI variant to strip. So "CLI without ArduPilot" is literally
# the stock install ISO. Two ways to produce one:
#
#   MODE=build     (default) - fetch src.tgz + xsrc.tgz, run build.sh to
#                              cross-build tools + release + iso-image.
#                              Takes ~1-2 hours on a 4-core VM. Works on
#                              NetBSD, Linux, and other Unix hosts.
#
#   MODE=download  - fetch the prebuilt stock ISO from cdn.NetBSD.org and
#                    verify SHA512. Takes ~1 minute. Not "from source" but
#                    useful for smoke-testing or as a base for stage 2 of
#                    the ArduPilot ISO.
#
# Usage:
#   ./build-netbsd-cli-iso.sh                              # default: build
#   MODE=download ./build-netbsd-cli-iso.sh
#   RELEASE=11.0 MACHINE=amd64 ./build-netbsd-cli-iso.sh   # override targets

set -euo pipefail

MODE=${MODE:-build}
RELEASE=${RELEASE:-11.0}    # 11.0 final. For an RC use e.g. RELEASE=11.0_RC6.
MACHINE=${MACHINE:-amd64}
JOBS=${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}
WORKDIR=${WORKDIR:-$PWD/netbsd-build}
OUT=${OUT:-$PWD/netbsd-${RELEASE}-${MACHINE}-cli.iso}
MIRROR=${MIRROR:-https://cdn.NetBSD.org/pub/NetBSD}

mkdir -p "$WORKDIR"
cd "$WORKDIR"

# ============================================================
#  MODE=download - just grab the stock CD image
# ============================================================
if [ "$MODE" = "download" ]; then
    URL=$MIRROR/images/NetBSD-${RELEASE}-${MACHINE}.iso
    echo "==> downloading stock ISO from $URL"
    curl -fL --retry 3 -o "$OUT" "$URL" \
        || wget -c -O "$OUT" "$URL"
    # SHA512 sums live next to the ISO in a file named 'checksums' or the
    # per-arch iso.txt; fetch and check whichever is available.
    curl -fLs "$URL.sha512" -o "$OUT.sha512" 2>/dev/null && \
        (cd "$(dirname "$OUT")" && sha512sum -c "$(basename "$OUT").sha512") \
        || echo "    (no .sha512 sidecar published; skipping checksum)"
    ls -lh "$OUT"
    echo "==> done: $OUT"
    exit 0
fi

# ============================================================
#  MODE=build - from-source with build.sh
# ============================================================

# --- 1. Fetch and unpack the source sets --------------------------------
# Extension caveat: NetBSD 11.0 final publishes source sets as .tgz
# (per ftp.NetBSD.org/pub/NetBSD/NetBSD-11.0/source/sets/syssrc.tgz).
# RC builds and some mirror layouts use .tar.xz. We probe .tgz first
# (matching the 11.0 default), fall back to .tar.xz, and pick the tar
# decompression flag to match.
SETS_URL=$MIRROR/NetBSD-${RELEASE}/source/sets
# Four source sets on the CDN (per source/sets/ listings for 9.0/10.0/11.0):
#   src.tgz       everything under /usr/src NOT in the three below,
#                 including build.sh, bin/, sbin/, distrib/, tools/, ...
#   syssrc.tgz    kernel: sys/ + config(1)
#   gnusrc.tgz    imported GNU tools (gcc, gdb, groff, ...)
#   sharesrc.tgz  /usr/share/ (man pages, docs, examples)
# xsrc (X11) is intentionally skipped; build.sh release doesn't need it.
for tgz in src syssrc gnusrc sharesrc; do
    if [ -f "$WORKDIR/.${tgz}.done" ]; then
        continue
    fi
    fetched=""
    for ext in tgz tar.xz; do
        echo "==> trying ${tgz}.${ext}"
        if curl -fL --retry 3 --fail -o "${tgz}.${ext}" \
                "$SETS_URL/${tgz}.${ext}"; then
            fetched=$ext
            break
        fi
        rm -f "${tgz}.${ext}"
    done
    [ -n "$fetched" ] || {
        echo "ERROR: neither ${tgz}.tar.xz nor ${tgz}.tgz at $SETS_URL" >&2
        exit 1
    }
    # -J for xz, -z for gzip.  -p preserves perms.
    case "$fetched" in
        tar.xz) tar -xJpf "${tgz}.${fetched}" ;;
        tgz)    tar -xzpf "${tgz}.${fetched}" ;;
    esac
    touch "$WORKDIR/.${tgz}.done"
    rm -f "${tgz}.${fetched}"
done

# --- 2. build.sh: tools -> release -> iso-image -------------------------
# -U     unprivileged build (don't need root)
# -u     don't rebuild what's already up to date
# -j N   parallel make
# -m M   target machine (amd64)
# -O D   objdir (all intermediates)
# -X D   xsrc dir (we skip X but build.sh insists on the path existing)
# We run each step separately so a failure in one is easy to resume.
# src sets unpack under ./usr/src/ (that's why the traditional command
# is `cd / ; tar -xzpf syssrc.tgz`, landing files at /usr/src). Since we
# extracted at $WORKDIR, the tree is at $WORKDIR/usr/src.
cd usr/src
OBJDIR=$WORKDIR/obj
BUILDSH="./build.sh -U -u -j${JOBS} -m ${MACHINE} -O ${OBJDIR}"

echo "==> build.sh tools (~10-30 min)"
$BUILDSH tools

echo "==> build.sh release (~1-2 h)"
# `release` = distribution + kernels + sets + release layout, per release(7).
# This is what populates $OBJDIR/releasedir/$MACHINE/binary/sets/*.tar.xz.
$BUILDSH release

echo "==> build.sh iso-image (fast; assembles CD from the release layout)"
$BUILDSH iso-image

# Result lands here per BUILDING(7):
ISO=$(ls "$OBJDIR/releasedir/images/"NetBSD-*-${MACHINE}.iso | head -1)
[ -f "$ISO" ] || { echo "ERROR: iso not produced" >&2; exit 1; }

cp "$ISO" "$OUT"
ls -lh "$OUT"
echo "==> done: $OUT"
