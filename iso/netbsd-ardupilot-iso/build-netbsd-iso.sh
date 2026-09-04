#!/usr/bin/env bash
# build-netbsd-iso.sh - master orchestrator.
#
# Produces a custom NetBSD 11.0_RC4 install ISO with ArduPilot and all
# its build dependencies pre-loaded, ready to pkg_add + run after sysinst.
#
# Two-stage design (each stage needs a different host):
#   Stage 1 runs on a NetBSD 11 host with our earlier install scripts
#           already applied. It packages the installed pkgsrc pkgs and
#           the built ArduPilot repo into payload.tar.xz.
#   Stage 2 runs anywhere with xorriso (Linux, NetBSD, macOS). It splices
#           the payload into a copy of the base NetBSD install ISO,
#           preserving El Torito boot.
#
# Usage:
#   ./build-netbsd-iso.sh stage1                       # on the NetBSD host
#   ./build-netbsd-iso.sh stage2 <base.iso> <out.iso>  # anywhere with xorriso
#   ./build-netbsd-iso.sh all   <base.iso> <out.iso>   # both, if on NetBSD

set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)

case "${1:-}" in
    stage1) shift; exec "$HERE/stage1-build-payload.sh" "$@" ;;
    stage2) shift; exec "$HERE/stage2-remaster-iso.sh"  "$@" ;;
    all)
        shift
        "$HERE/stage1-build-payload.sh"
        exec "$HERE/stage2-remaster-iso.sh" "$@"
        ;;
    *)
        cat <<EOF
usage: $0 stage1
       $0 stage2 <base-netbsd.iso> <output.iso>
       $0 all    <base-netbsd.iso> <output.iso>
EOF
        exit 1
        ;;
esac
