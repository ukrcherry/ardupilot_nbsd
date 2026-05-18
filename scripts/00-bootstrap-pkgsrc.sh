#!/bin/sh
# 00-bootstrap-pkgsrc.sh
#
# POSIX sh (not bash) - this is the FIRST script and bash isn't installed yet.
#
# What this does:
#   1. Ensure a pkgsrc tree exists at $PKGSRC_DIR (extract tarball if missing).
#   2. Write a minimal mk.conf that turns on a few useful options.
#   3. Build & install shells/bash from source via pkgsrc, so the rest of the
#      scripts can use bash.
#
# All subsequent scripts can assume /usr/pkg/bin/bash exists.

set -eu

# Source the shared env. "." is POSIX equivalent of bash's "source".
. "$(dirname "$0")/../env.sh"

echo "==> Bootstrap step 00: pkgsrc tree + mk.conf + bash"

# --- 0. Verify the 'comp' distribution set is installed -------------------
# Without comp.tgz, /usr/include is mostly empty and EVERY pkgsrc build
# fails with "<package> requires a working dlopen()" because pkgsrc cannot
# compile its dlopen probe in mk/dlopen.builtin.mk. The canary symptom is
# /usr/bin/lex missing; the root cause is comp.tgz not extracted at install.
# Diagnosed on the netbsd-current-users list by Martin Husemann and matthew
# green, July 2021:
#   http://mail-index.netbsd.org/current-users/2021/07/10/msg041251.html
if [ ! -f /usr/include/dlfcn.h ] || [ ! -x /usr/bin/lex ]; then
    echo "    'comp' distribution set is missing - pkgsrc cannot build without it."
    echo "    Fetching comp/man/misc sets for NetBSD-${NETBSD_RELEASE}/${NETBSD_ARCH}"
    echo "    from ${NETBSD_SETS_URL}"
    for set in comp man misc; do
        echo "      -> ${set}.tgz"
        # Stream tarball straight into tar(1) and extract at /, the layout
        # inside the tarball is rooted at ./usr/... so tar lands files
        # exactly where sysinst would have put them.
        sudo ftp -V -o - "${NETBSD_SETS_URL}/${set}.tgz" \
            | sudo tar -xzpf - -C / \
            || { echo "ERROR: failed to install ${set}.tgz" >&2; exit 1; }
    done
    # Belt-and-braces re-check.
    if [ ! -f /usr/include/dlfcn.h ] || [ ! -x /usr/bin/lex ]; then
        echo "ERROR: comp set extracted but expected files still missing." >&2
        exit 1
    fi
    echo "    comp/man/misc sets installed."
else
    echo "    comp set OK (/usr/include/dlfcn.h and /usr/bin/lex present)"
fi

# --- 1. pkgsrc tree -------------------------------------------------------
# NetBSD ships pkgsrc separately; a fresh install often has no tree at all.
# We pull the quarterly-stable tarball over HTTPS. About 75 MB compressed.
if [ ! -d "$PKGSRC_DIR/mk" ]; then
    echo "    pkgsrc tree not found at $PKGSRC_DIR; fetching ${PKGSRC_BRANCH}.tar.gz"
    sudo mkdir -p "$(dirname "$PKGSRC_DIR")"
    cd "$(dirname "$PKGSRC_DIR")"
    # Use base ftp(1) which on NetBSD speaks HTTPS just fine.
    sudo ftp -V -o "${PKGSRC_BRANCH}.tar.gz" \
        "https://cdn.NetBSD.org/pub/pkgsrc/${PKGSRC_BRANCH}/pkgsrc.tar.gz"
    sudo tar -xzpf "${PKGSRC_BRANCH}.tar.gz"
    # The tarball expands to ./pkgsrc, which is what we want.
    sudo rm -f "${PKGSRC_BRANCH}.tar.gz"
else
    echo "    pkgsrc tree already present at $PKGSRC_DIR (skipping fetch)"
fi

# --- 2. mk.conf -----------------------------------------------------------
# Minimal config: allow building anything (some packages have license tags),
# parallelise gcc compiles, and keep work directories so debugging failed
# builds is easier.
MK_CONF=/etc/mk.conf
if ! sudo test -f "$MK_CONF" || ! sudo grep -q "ardupilot-netbsd-pkgsrc" "$MK_CONF"; then
    echo "    writing $MK_CONF"
    sudo sh -c "cat >> $MK_CONF" <<EOF
# --- added by ardupilot-netbsd-pkgsrc/00-bootstrap-pkgsrc.sh ---
ACCEPTABLE_LICENSES+=    gnu-gpl-v3 gnu-lgpl-v3 gnu-gpl-v2 gnu-lgpl-v2 \\
                          modified-bsd 2-clause-bsd-license original-bsd \\
                          mit cc-by-sa-v4.0 apache-2.0 \\
                          unlimited-redistribution arm-ds-license
MAKE_JOBS=               $(sysctl -n hw.ncpu 2>/dev/null || echo 2)
PKG_DEFAULT_OPTIONS+=    inet6
SKIP_LICENSE_CHECK=      YES
# Keep work dirs for postmortem on failed builds; remove this line for prod.
# CLEANDEPENDS=          YES
EOF
fi

# --- 3. bash from source --------------------------------------------------
# shells/bash is needed for the rest of the scripts and for ArduPilot's
# Tools/scripts/*.sh which heavily use bash-isms.
# `make replace` (vs `make install`) cleanly handles re-runs.
if [ ! -x "$LOCALBASE/bin/bash" ]; then
    echo "    building shells/bash from source"
    cd "$PKGSRC_DIR/shells/bash"
    sudo make CLEANDEPENDS=YES install clean clean-depends
else
    echo "    $LOCALBASE/bin/bash already present (skipping)"
fi

# Optional: add /usr/pkg/bin/bash to /etc/shells so chsh(1) accepts it.
if ! grep -q "^$LOCALBASE/bin/bash$" /etc/shells 2>/dev/null; then
    echo "$LOCALBASE/bin/bash" | sudo tee -a /etc/shells >/dev/null
fi

echo "==> Step 00 done. bash is at $LOCALBASE/bin/bash"
echo "    Subsequent scripts will use #!/usr/pkg/bin/bash"
