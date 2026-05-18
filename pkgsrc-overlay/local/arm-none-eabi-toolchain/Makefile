# $NetBSD$
#
# arm-none-eabi-toolchain - bare-metal ARM cross compiler suite
#
# Local pkgsrc package: builds binutils + gcc + newlib + libstdc++ for
# arm-none-eabi targets, suitable for ArduPilot's MatekH743 (STM32H7) build.
#
# Why a local package instead of cross/arm-none-eabi-gcc?
#   The in-tree pkgsrc package is stuck at gcc 8.3.0, but ArduPilot requires
#   g++ >= 10.2.1 (it uses C++17 features and post-C++14 std::optional, etc.).
#   This Makefile pulls fresh upstream tarballs and runs the canonical ARM
#   GNU Toolchain build sequence:
#       1. binutils for arm-none-eabi
#       2. first-stage gcc (C only, no libc)
#       3. newlib (C standard library for bare-metal)
#       4. second-stage gcc (full C++, libstdc++ using newlib)
#
# Everything installs under ${PREFIX}/cross/arm-none-eabi/ so it doesn't
# collide with the system or with the in-tree cross/* packages.

DISTNAME=       arm-none-eabi-toolchain-13.2.0
PKGNAME=        cross-arm-none-eabi-toolchain-13.2.0
CATEGORIES=     cross devel
# We have multiple DISTFILES; MASTER_SITES is overridden per-file below.
MASTER_SITES=   # empty - see SITES.* overrides

# Per-file source archives. pkgsrc supports this via SITES.<filename>.
BINUTILS_VER=   2.42
GCC_VER=        13.2.0
NEWLIB_VER=     4.4.0.20231231

DISTFILES=      binutils-${BINUTILS_VER}.tar.xz \
                gcc-${GCC_VER}.tar.xz \
                newlib-${NEWLIB_VER}.tar.gz

SITES.binutils-${BINUTILS_VER}.tar.xz= \
                https://ftp.gnu.org/gnu/binutils/ \
                https://ftpmirror.gnu.org/binutils/
SITES.gcc-${GCC_VER}.tar.xz= \
                https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VER}/ \
                https://ftpmirror.gnu.org/gcc/gcc-${GCC_VER}/
SITES.newlib-${NEWLIB_VER}.tar.gz= \
                ftp://sourceware.org/pub/newlib/ \
                https://sourceware.org/pub/newlib/

MAINTAINER=     local@localhost
HOMEPAGE=       https://developer.arm.com/Tools%20and%20Software/GNU%20Toolchain
COMMENT=        GCC ${GCC_VER} cross compiler for bare-metal ARM (arm-none-eabi)
LICENSE=        gnu-gpl-v3 AND gnu-lgpl-v3

# --- Build deps (host tools needed to compile the cross compiler) -------
# GCC's bootstrap needs all three multi-precision math libs.
USE_TOOLS+=     gmake makeinfo
BUILD_DEPENDS+= bison-[0-9]*:../../devel/bison
BUILD_DEPENDS+= flex-[0-9]*:../../devel/flex
DEPENDS+=       gmp>=6.2:../../devel/gmp
DEPENDS+=       mpfr>=4.1:../../math/mpfr
DEPENDS+=       mpcomplex>=1.2:../../math/mpcomplex

# We're not building this for a particular OS; cross-compilers target
# "none" (bare metal). The flag below tells pkgsrc not to try to wrap
# the resulting binaries with its standard compiler wrappers.
NO_CONFIGURE=   yes              # we run configure manually per-stage
USE_LANGUAGES=  c c++

# Install path - keeps everything under one prefix.
TC_PREFIX=      ${PREFIX}/cross/arm-none-eabi
TARGET=         arm-none-eabi

# Shared configure flags for binutils and both gcc stages.
COMMON_CONFIG= \
    --target=${TARGET} \
    --prefix=${TC_PREFIX} \
    --with-sysroot=${TC_PREFIX}/${TARGET} \
    --disable-nls \
    --disable-shared \
    --disable-werror

# GCC-specific flags. -j is filled in from MAKE_JOBS by pkgsrc.
GCC_CONFIG= \
    --enable-languages=c,c++ \
    --with-newlib \
    --with-headers=${WRKSRC}/newlib-${NEWLIB_VER}/newlib/libc/include \
    --disable-libssp \
    --disable-libstdcxx-pch \
    --disable-decimal-float \
    --disable-libffi \
    --disable-libgomp \
    --disable-libmudflap \
    --disable-libquadmath \
    --disable-tls \
    --with-gnu-as --with-gnu-ld \
    --enable-multilib

# pkgsrc gives us:
#   WRKSRC          = the directory tar -xf'd from the first DISTFILE.
# We instead want WRKDIR (parent of WRKSRC) so all three sources sit
# side-by-side: WRKDIR/{binutils-,gcc-,newlib-}
WRKSRC=         ${WRKDIR}

# --- Custom multi-stage build target ------------------------------------
# pkgsrc's normal do-build target runs `make` in WRKSRC, which doesn't
# fit a multi-stage cross-toolchain. We override it.

do-build:
        # --- Stage 1: binutils ------------------------------------------
        ${MKDIR} ${WRKDIR}/build-binutils
        cd ${WRKDIR}/build-binutils && \
            ${WRKDIR}/binutils-${BINUTILS_VER}/configure ${COMMON_CONFIG} && \
            ${MAKE_PROGRAM} -j${MAKE_JOBS} && \
            ${MAKE_PROGRAM} install
        # binutils now lives in ${TC_PREFIX}; add it to PATH for next stages.
        # Stage 2: first-stage gcc (C only, no libc) ---------------------
        ${MKDIR} ${WRKDIR}/build-gcc-stage1
        cd ${WRKDIR}/build-gcc-stage1 && \
            PATH=${TC_PREFIX}/bin:$$PATH \
            ${WRKDIR}/gcc-${GCC_VER}/configure ${COMMON_CONFIG} ${GCC_CONFIG} \
                --without-headers \
                --enable-languages=c \
                --disable-libstdcxx && \
            PATH=${TC_PREFIX}/bin:$$PATH ${MAKE_PROGRAM} -j${MAKE_JOBS} all-gcc && \
            PATH=${TC_PREFIX}/bin:$$PATH ${MAKE_PROGRAM} install-gcc
        # Stage 3: newlib ------------------------------------------------
        ${MKDIR} ${WRKDIR}/build-newlib
        cd ${WRKDIR}/build-newlib && \
            PATH=${TC_PREFIX}/bin:$$PATH \
            ${WRKDIR}/newlib-${NEWLIB_VER}/configure \
                --target=${TARGET} \
                --prefix=${TC_PREFIX} \
                --disable-newlib-supplied-syscalls \
                --enable-newlib-reent-small \
                --disable-nls && \
            PATH=${TC_PREFIX}/bin:$$PATH ${MAKE_PROGRAM} -j${MAKE_JOBS} && \
            PATH=${TC_PREFIX}/bin:$$PATH ${MAKE_PROGRAM} install
        # Stage 4: full gcc with C++ and libstdc++ on top of newlib ------
        ${MKDIR} ${WRKDIR}/build-gcc-stage2
        cd ${WRKDIR}/build-gcc-stage2 && \
            PATH=${TC_PREFIX}/bin:$$PATH \
            ${WRKDIR}/gcc-${GCC_VER}/configure ${COMMON_CONFIG} ${GCC_CONFIG} && \
            PATH=${TC_PREFIX}/bin:$$PATH ${MAKE_PROGRAM} -j${MAKE_JOBS} && \
            PATH=${TC_PREFIX}/bin:$$PATH ${MAKE_PROGRAM} install

# pkgsrc's PLIST mechanism wants to know every file installed. For a
# multi-thousand-file toolchain that's painful; we use PLIST_TYPE=dynamic
# which records whatever ends up under TC_PREFIX during install.
PLIST_SRC=      # empty - generated dynamically
GENERATE_PLIST= cd ${TC_PREFIX} && find . -type f -o -type l | \
                sed -e 's|^\./|cross/arm-none-eabi/|' | sort

.include "../../mk/bsd.pkg.mk"
