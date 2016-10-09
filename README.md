# Machinekit Builder v. 3

This builds a Docker image containing `multistrap` system root trees
for Debian Jessie `armhf` (and `i386` in the future) architecture,
with tools in the native system to cross-build Machinekit.

These containers are suitable for use either interactively on a
workstation or in automated build environments like Travis CI.

Right now, this build method is still under initial evaluation.  While
the RIP build result will pass regression tests on a native ARM host,
and while the Debian packages will build, most functionality has never
been tested.  Build results may have unpredicted results, and are
**only suited for testing in simulated development environments**.

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

- Build Machinekit packages
  - Prepare the source (as usual)

		  debian/configure -prxt 8.6

  - Build `amd64` and architecture independent binary packages (as usual)

		  dpkg-buildpackage -uc -us -b

  - Build `armhf` binary packages

		  SYSROOT=$ARM_ROOT dpkg-buildpackage -uc -us -a armhf -B -d

- Build Machinekit RIP
  - Init `autoconf` (as usual)

		  cd src && ./autogen.sh

  - Configure and build for `amd64`

		  ./configure && make

  - Configure and build for `armhf`

		  CPPFLAGS=--sysroot=$ARM_ROOT LDFLAGS=--sysroot=$ARM_ROOT \
		  ./configure \
			  --host=$ARM_HOST_MULTIARCH \
			  --with-tcl=$ARM_ROOT/usr/lib/$ARM_HOST_MULTIARCH/tcl8.6 \
			  --with-tk=$ARM_ROOT/usr/lib/$ARM_HOST_MULTIARCH/tk8.6 \
		  CPPFLAGS=--sysroot=$ARM_ROOT LDFLAGS=--sysroot=$ARM_ROOT make

  - Setuid (as usual)

		  sudo make setuid

## How it works

This `Dockerfile` bootstraps foreign-arch system roots (using
`multiarch`) with needed host-architecture dependencies installed.  It
makes a few adjustments to links and package build tools, and installs
the Emdebian `armhf` cross-compile tool chain.  The commands above to
cross-build Machinekit instruct the compilers, linkers and build tools
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


## TODO

- Test build viability
  - Currently, RIP builds are known to pass regression tests (the
    built source tree must be copied to an ARM host with Machinekit
    run-time dependencies installed to test).
  - Packages have not been tested.  Their viability must be determined
    before taking this project further.
- Wheezy builds
  - Using this method to build Wheezy packages is expected to be a
    much greater challenge than Jessie, since `Multi-Arch:` support is
    even less mature.
- Other achitectures:  `i386` and native `amd64` builds
  - Native builds should be trivial.
  - This same method should be easily extended to build
    `i386`-architecture packages.
  - Raspberry Pi builds could be challenging, since package versions
    between Raspbian and upstream Jessie may not match.  This method
    may break down in that case.
