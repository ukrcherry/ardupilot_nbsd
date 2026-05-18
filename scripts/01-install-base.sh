#!/usr/pkg/bin/bash
# 01-install-base.sh
#
# Builds and installs ArduPilot's core build prerequisites via pkgsrc
# source builds. Each `make install` in a pkgsrc package directory will:
#   1. Fetch the upstream source tarball
#   2. Verify its checksum against distinfo
#   3. Apply patches from patches/
#   4. Configure, build, and install under $LOCALBASE (/usr/pkg)
#
# This is the same workflow you'd use to develop a new pkgsrc package -
# nothing here pulls a pre-built binary.

set -euo pipefail

source "$(dirname "$0")/../env.sh"

echo "==> Step 01: building base development tools from pkgsrc source"

# Helper: build & install one pkgsrc package, but skip if already present.
# Args: $1 = pkgsrc category/subdir, e.g. "devel/git-base"
#       $2 = pkg name prefix to test for installation, e.g. "git-base"
pkg_build() {
    local path="$1"
    local probe="$2"
    if pkg_info -e "${probe}" >/dev/null 2>&1; then
        echo "    [skip] $path (already installed)"
        return 0
    fi
    echo "    [build] $path"
    cd "$PKGSRC_DIR/$path"
    sudo make install clean clean-depends
}

# --- Core toolchain ------------------------------------------------------
# NetBSD 11 base already ships gcc 12.x, so we don't need gcc from pkgsrc
# for the SITL/host build. But ArduPilot's wscript expects "make" =GNU make,
# not BSD make. devel/gmake is therefore essential.
pkg_build devel/gmake               gmake

# gawk: ArduPilot's Tools/scripts use GNU extensions (gensub, asort, etc.)
pkg_build lang/gawk                 gawk

# ccache: optional but ArduPilot's build expects /usr/lib/ccache shim path.
# We won't symlink into /usr/lib/ccache because NetBSD's /usr/lib is base;
# instead we expose ccache via PATH. See 05-build-test.sh for the wiring.
pkg_build devel/ccache              ccache

# Git: pulling ArduPilot + many submodules (ChibiOS, mavlink, waf, etc.).
pkg_build devel/git-base            git-base
pkg_build devel/git-docs            git-docs    # man pages - small, useful

# wget: used by ArduPilot's bootloader/firmware download helpers.
pkg_build net/wget                  wget

# pkg-config: waf's configure step probes libraries via pkg-config.
pkg_build devel/pkgconf             pkgconf

# libtool: required by some Python wheel builds (lxml in particular).
pkg_build devel/libtool             libtool

# zlib, libxml2, libxslt: lxml needs these; ArduPilot needs lxml.
pkg_build devel/zlib                zlib
pkg_build textproc/libxml2          libxml2
pkg_build textproc/libxslt          libxslt

# A modern GCC isn't strictly required for SITL on NetBSD 11 (base has 12),
# but if your NetBSD is older or if base gcc misbehaves on a particular
# ArduPilot file, uncomment this:
# pkg_build lang/gcc14              gcc14

# --- User permissions ----------------------------------------------------
# On Linux ArduPilot puts users in `dialout` for serial access.
# NetBSD equivalent is the `dialer` group (see man tty(4), uucp).
if ! id -nG "$USER" | grep -qw dialer; then
    echo "    adding $USER to group 'dialer' (for /dev/tty* access)"
    sudo usermod -G dialer "$USER" || sudo /usr/sbin/usermod -G dialer "$USER"
    echo "    NOTE: log out and back in for the group change to take effect."
fi

echo "==> Step 01 done."
