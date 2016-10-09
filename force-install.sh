#!/bin/bash

PACKAGES="libboost-python1.55-dev:armhf libboost-python-dev:armhf"
PACKAGE_DIR=/tmp/pkg-downloads

if test "$1" = "-i"; then
    # install
    cd $PACKAGE_DIR
    dpkg -i --force-depends *.deb

elif test "$1" = "-r"; then
    # remove
    dpkg -r $PACKAGES

else
    # usage
    echo "Usage:  $0 [-i|-r]" >&2
    exit 1
fi
