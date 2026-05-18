# ArduPilot on NetBSD 11.0_RC4 via pkgsrc (source build)

A set of bash scripts to bootstrap an ArduPilot build environment on
**NetBSD 11.0_RC4 amd64** using **pkgsrc** to compile every dependency
**from source** (no binary `pkg_add` of third-party packages, except the
unavoidable bootstrap of `bash` itself, which we also compile via pkgsrc).

Goal: at the end you can run, inside the cloned `ardupilot/` tree:

    ./waf configure
    ./waf all
    ./waf configure --board MatekH743
    ./waf copter


## IMPORTANT — read first

**ArduPilot does not officially support NetBSD.** The Linux/SITL HAL has
some Linux-isms (epoll, /proc, Linux-specific socket options) that may
need small patches before `./waf all` succeeds. This script set gets you
*all the way through* the dependency installation and clone, and runs
the `waf configure` / build commands; if a particular SITL source file
fails to compile because of a missing Linux header, you will need to
patch that file (the cross / MatekH743 build is much more likely to work
out of the box because that target uses ChibiOS — bare-metal — and only
needs the ARM cross-toolchain).

This is also why we pin to `--board MatekH743` (which is the user's
stated end goal): the cross build for an STM32H7 board is the most
portable target.

Two known dependency-version pitfalls that the scripts handle:

1. **`cross/arm-none-eabi-gcc` in pkgsrc is gcc 8.3.0** — ArduPilot needs
   `g++ >= 10.2.1`. Script `03` therefore writes a *local* pkgsrc package
   under `localbase/pkgsrc/local/arm-none-eabi-toolchain/` that builds
   binutils 2.42 + gcc 13.2.0 + newlib 4.4.0 from upstream tarballs
   using pkgsrc infrastructure.
2. **`empy` must be 3.3.4**, not the 4.x on PyPI. Script `02` pins it.


## NetBSD specifics worth knowing

* Default shell is `/bin/sh` (not bash). The first script (`00`) is
  POSIX-sh so it can run on a brand-new install. After it installs bash
  via pkgsrc, the rest use `#!/usr/pkg/bin/bash`.
* Serial-port group is **`dialer`** on NetBSD (not `dialout`).
* Base `make(1)` is BSD make. pkgsrc on NetBSD uses base `make`, so we
  call it as `make` (not `bmake`, which would be needed on Linux/macOS).
* Default install prefix for pkgsrc on NetBSD is `/usr/pkg`. The
  toolchain we build lands under `/usr/pkg/cross/arm-none-eabi/`.
* The **`comp` distribution set must be installed** (it holds
  `/usr/include`, static libs, `lex(1)`, `yacc(1)`, etc.). Without it,
  every pkgsrc build fails with the cryptic
  `<package> requires a working dlopen()` because pkgsrc can't compile
  its dlopen probe. Script `00` auto-detects this and fetches
  `comp.tar.xz` from the CDN if missing (NetBSD 11 ships sets as
  xz-compressed `.tar.xz`, not the older `.tgz`). If you ever see the
  dlopen error elsewhere, this is the cause.


## Choosing a pkgsrc branch

The default is `pkgsrc-2026Q1` (the latest quarterly as of May 2026).
Override at invocation time:

    PKGSRC_BRANCH=pkgsrc-2025Q4 sh ./install-all.sh   # older quarterly
    PKGSRC_BRANCH=current       sh ./install-all.sh   # rolling dev tree

The URL path component is exactly the value of `PKGSRC_BRANCH`. For
"current" use the literal string `current`, not `pkgsrc-current`. The
custom ARM-toolchain overlay in step 03 is needed regardless of branch
— even on `current`, in-tree `cross/arm-none-eabi-gcc` is still 8.3.0.


## Files

    README.md                              this file
    install-all.sh                         runs every step in order
    env.sh                                 paths & versions shared by all scripts
    scripts/00-bootstrap-pkgsrc.sh         get pkgsrc tree + mk.conf + bash
    scripts/01-install-base.sh             gmake, git, gawk, ccache, wget, gcc, pkgconf
    scripts/02-install-python-deps.sh      python 3.12 + pip-installed AP modules in a venv
    scripts/03-install-arm-toolchain.sh    custom local pkgsrc pkg for gcc 13.2 cross
    scripts/04-clone-ardupilot.sh          clone + recursive submodules
    scripts/05-build-test.sh               run the four ./waf commands

    pkgsrc-overlay/local/arm-none-eabi-toolchain/
                                           the custom pkgsrc Makefile + helpers


## Usage

    # On a fresh NetBSD 11.0_RC4 amd64 install, as a normal user with
    # sudo configured (the scripts use sudo for the pkgsrc install steps):

    tar xzf ardupilot-netbsd-pkgsrc.tar.gz
    cd ardupilot-netbsd-pkgsrc
    sh ./install-all.sh

Total wall-clock time on a 4-core VM is roughly 90–120 minutes; almost
all of that is the cross-gcc build in step 03.


## Running individual steps

The numbered scripts are independent and can be re-run. If, say, the
ARM toolchain step fails partway, fix the issue and re-run:

    /usr/pkg/bin/bash scripts/03-install-arm-toolchain.sh

The very first script (`00-bootstrap-pkgsrc.sh`) is the only one written
in POSIX sh, since bash isn't installed yet at that point.
