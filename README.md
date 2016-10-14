# Docker Cross-Builder

This builds a Docker image containing `multistrap` system root trees
for Debian Jessie `armhf` and `i386` architectures, with tools in the
native system to cross-build Debian packages.

The container is meant to be built upon by other containers, adding
build dependencies and sysroot tweaks.

These containers are suitable for use either interactively on a
workstation or in automated build environments like Travis CI.

Right now, this build method is still under initial evaluation.  Build
results may have unpredicted results, and are **only suited for
testing in simulated development environments**.

## Using the builder

- Pull or build the Docker image
  - Pull image, `jessie` tag, from Docker Hub

            docker pull zultron/mk-builder-3:jessie

  - Or, build image from `Dockerfile`
	- Clone this repository and `cd` into the directory

            git clone https://github.com/zultron/mk-builder-3.git
			cd mk-builder-3

	- Customize the *Set up environment* section the `Dockerfile` as
	  needed
	  - For interactive use, it may be practical to set `$UID` and
		 `$GID` to match those outside the container.
	- Build Docker image

	        ./mk-builder.sh build

- Start the Docker image
  - If `$MK_BUILDER` is the path to this clone (and `$MK` is the path
    to the Machinekit clone)

            cd $MK
            $MK_BUILDER/mk-builder.sh

- Building packages
  - Prepare the source (as usual)
  - Build `amd64` and architecture independent binary packages (as usual)

          dpkg-buildpackage -uc -us -b

  - Build `i386` binary packages

          DPKG_ROOT=$I386_ROOT \
          LDFLAGS="-m32 --sysroot=$I386_ROOT" \
          CPPFLAGS="-m32 --sysroot=$I386_ROOT" \
          dpkg-buildpackage -uc -us -a i386 -B -d

  - Build `armhf` binary packages

          DPKG_ROOT=$ARM_ROOT \
          LDFLAGS=--sysroot=$ARM_ROOT \
          CPPFLAGS=--sysroot=$ARM_ROOT \
          dpkg-buildpackage -uc -us -a armhf -B -d

  - Build Raspbian binary packages

          DPKG_ROOT=$RPI_ROOT \
          LDFLAGS=--sysroot=$RPI_ROOT \
          CPPFLAGS=--sysroot=$RPI_ROOT \
          dpkg-buildpackage -uc -us -a armhf -B -d

- Build by hand
  - Init `autoconf` (as usual)

          ./autogen.sh

  - Configure and build for `amd64`

          ./configure
          make

  - Configure and build for `i386`

          CPPFLAGS="--sysroot=$I386_ROOT -m32"
          LDFLAGS="--sysroot=$I386_ROOT -m32" \
          ./configure --host=$I386_HOST_MULTIARCH

          CPPFLAGS="--sysroot=$I386_ROOT -m32" \
          LDFLAGS="--sysroot=$I386_ROOT -m32" \
          make -j4

  - Configure and build for `armhf`

          CPPFLAGS=--sysroot=$ARM_ROOT \
          LDFLAGS=--sysroot=$ARM_ROOT \
          ./configure --host=$ARM_HOST_MULTIARCH

          CPPFLAGS=--sysroot=$ARM_ROOT \
          LDFLAGS=--sysroot=$ARM_ROOT \
          make

  - Configure and build for Raspbian

          CPPFLAGS=--sysroot=$RPI_ROOT \
          LDFLAGS=--sysroot=$RPI_ROOT \
          ./configure --host=$ARM_HOST_MULTIARCH

          CPPFLAGS=--sysroot=$RPI_ROOT \
          LDFLAGS=--sysroot=$RPI_ROOT \
          make

  - Setuid (as usual)

          sudo make setuid

## How it works

This `Dockerfile` bootstraps foreign-arch system roots (using
`multiarch`) with needed host-architecture dependencies installed.  It
makes a few adjustments to links and package build tools, and installs
the Emdebian `armhf` cross-compile tool chain.  The commands above to
cross-build packages instruct the compilers, linkers and build tools
to look for architecture-specific headers, libraries and build
configuration under the foreign-arch system root.

This method works around the rapidly progressing but still not yet
complete Debian `Multi-Arch:` support, where packages not yet
`Multi-Arch:`-aware may not have foreign-arch versions installed next
to or instead of native-arch versions, and cross-build dependencies
cannot be satisfied.  Even once `Multi-Arch:` works to build against
Debian mainline package streams, someday, this method also enables
building against e.g. a Raspbian system root, where lagging package
versions are sufficient to break `Multi-Arch:` package installation.
