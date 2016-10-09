#!/bin/bash -xe

case "$1" in
    armhf)
	SYSROOT=$ARM_ROOT
	HOST_MULTIARCH=$ARM_HOST_MULTIARCH
	;;

    i386)
	SYSROOT=$I386_ROOT
	HOST_MULTIARCH=$I386_HOST_MULTIARCH
	;;

    amd64) # Build out of the root system
	SYSROOT=
	HOST_MULTIARCH=
	;;;

    *) echo "Usage:  $0 [ armhf | i386 ]" >&2; exit 1 ;;
esac

CPPFLAGS=--sysroot=$SYSROOT
LDFLAGS=--sysroot=$SYSROOT
PKG_CONFIG_PATH=$SYSROOT/usr/lib/$HOST_MULTIARCH/pkgconfig
PKG_CONFIG_PATH+=:$SYSROOT/usr/lib/pkgconfig

./autogen.sh
./configure \
    --host=$HOST_MULTIARCH \
    --with-tcl=$SYSROOT/usr/lib/$HOST_MULTIARCH/tcl8.6 \
    --with-tk=$SYSROOT/usr/lib/$HOST_MULTIARCH/tk8.6
