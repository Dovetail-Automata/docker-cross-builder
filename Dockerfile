FROM debian:jessie
MAINTAINER John Morris <john@zultron.com>

###################################################################
# Generic apt configuration

ENV TERM dumb

# apt config:  silence warnings and set defaults
ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN true
ENV LC_ALL C.UTF-8
ENV LANGUAGE C.UTF-8
ENV LANG C.UTF-8

# turn off recommends on container OS and proot OS
RUN echo 'APT::Install-Recommends "0";\nAPT::Install-Suggests "0";' > \
            /etc/apt/apt.conf.d/01norecommend && \
    mkdir -p ${ROOTFS}/etc/apt/apt.conf.d && \
    echo 'APT::Install-Recommends "0";\nAPT::Install-Suggests "0";' > \
            ${ROOTFS}/etc/apt/apt.conf.d/01norecommend

# use stable Debian mirror
RUN sed -i /etc/apt/sources.list -e 's/httpredir.debian.org/ftp.debian.org/'

###################################################################
# Configure 3rd-party apt repos, add foreign arches, and update OS

# install apt-transport-https for packagecloud.io
RUN apt-get update && \
    apt-get install -y apt-transport-https ca-certificates

# add emdebian package archive
ADD emdebian-toolchain-archive.key /tmp/
RUN apt-key add /tmp/emdebian-toolchain-archive.key && \
    echo "deb http://emdebian.org/tools/debian/ jessie main" > \
        /etc/apt/sources.list.d/emdebian.list

# add Machinekit package archive

RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 43DDF224
RUN echo 'deb http://deb.machinekit.io/debian jessie main' > \
        /etc/apt/sources.list.d/machinekit.list

# add foreign architectures
RUN dpkg --add-architecture armhf
RUN dpkg --add-architecture i386

# make sure linux-libc-dev isn't installed from the MK repo; because
# that kernel version doesn't match mainline kernels, the
# `linux-libc-dev` package will have different versions across
# architectures, and therefore conflict
RUN echo "Package: linux-libc-dev\nPin: version 3.*\nPin-Priority:" \
        "1001\n\nPackage: linux-libc-dev:armhf\nPin: " \
        "version 3.*\nPin-Priority: 1001" > \
        /etc/apt/preferences.d/10pin-linux-libc-dev

# update Debian OS
RUN apt-get update && \
    apt-get -y upgrade

###################################################################
# Install generic packages

# Stop `dpkg-gencontrol` warnings about flock
RUN apt-get -y install \
        libfile-fcntllock-perl

# Utilities
RUN apt-get -y install \
	locales \
	git \
	bzip2 \
	sharutils \
	net-tools \
	time \
	help2man \
	xvfb \
	xauth \
	python-sphinx \
	wget \
        sudo \
	lftp \
	multistrap \
	debian-keyring

# Dev tools
RUN apt-get install -y \
	build-essential \
	devscripts \
	fakeroot \
	equivs \
	lsb-release \
	less \
	python-debian \
	libtool \
	ccache \
	autoconf \
	automake \
	quilt

# Add packagecloud cli and prune utility
RUN	apt-get install -y python-restkit rubygems
RUN	gem install package_cloud --no-rdoc --no-ri
ADD	PackagecloudIo.py prune.py /usr/bin/

# Cross-build toolchain and qemulator
# For some reason, apt-get chokes without explicit `linux-libc-dev:armhf`
RUN apt-get -y install \
        crossbuild-essential-armhf \
        qemu-user-static \
	linux-libc-dev:armhf


###########################################
# Monkey-patch:  add `{dh_shlibdeps,dpkg-shlibdeps} --sysroot` argument

ADD dpkg-shlibdeps.patch /tmp/
RUN cd / && \
    patch -p0 < /tmp/dpkg-shlibdeps.patch && \
    rm /tmp/dpkg-shlibdeps.patch


###################################################################
# Install Machinekit dependency packages

#########
# Prepare to install deps for all arches

# Set up debian/control for `mk-build-deps`
#     FIXME download parts from upstream
ADD debian/ /tmp/debian/
RUN /tmp/debian/configure -prxt8.6

# Add multistrap configuration
ADD jessie.conf /tmp/

# Directory for `mk-build-deps` apt repository
RUN mkdir /tmp/debs && \
    touch /tmp/debs/Sources

# `run-configure` script
ADD run-configure.sh /usr/local/bin/run-configure

#########
# Install deps for native arch
RUN yes y | mk-build-deps -ir /tmp/debian/control

##############################
# Install armhf arch "sysroot"

# Create armhf deps package
RUN mk-build-deps -a armhf /tmp/debian/control && \
    mv *.deb /tmp/debs && \
    dpkg-scanpackages -m /tmp/debs > /tmp/debs/Packages

# Build armhf "sysroot"
ENV ARM_ROOT=/sysroot/armhf
ENV ARM_HOST_MULTIARCH=arm-linux-gnueabihf
RUN multistrap -f /tmp/jessie.conf -a armhf -d $ARM_ROOT

# armhf-arch pkg-config
RUN ln -s pkg-config /usr/bin/${ARMHF_HOST_MULTIARCH}-pkg-config

# Fix symlinks in "sysroot" libdir pointing to `/usr/lib`
RUN for link in $(find $ARM_ROOT/usr/lib/${ARMHF_HOST_MULTIARCH}/ -type l); do \
        if test $(dirname $(readlink $link)) != .; then \
	    ln -sf $ARM_ROOT$(readlink $link) $link; \
	fi; \
    done

# FIXME i386 arch support broken
# ##############################
# # Install i386 arch "sysroot"

# # Create i386 deps package
# RUN mk-build-deps -a i386 /tmp/debian/control && \
#     mv *.deb /tmp/debs && \
#     cd /tmp/debs && \
#     dpkg-scanpackages -m /tmp/debs > /tmp/debs/Packages

# # Build i386 "sysroot"
# ENV I386_ROOT=/sysroot/i386
# ENV I386_HOST_MULTIARCH=i386-linux-gnu
# RUN multistrap -f /tmp/jessie.conf -a i386 -d $I386_ROOT

# # i386-arch pkg-config
# RUN ln -s pkg-config /usr/bin/${I386_HOST_MULTIARCH}-pkg-config

# # Fix symlinks in "sysroot" libdir pointing to `/usr/lib`
# RUN for link in $(find $I386_ROOT/usr/lib/${I386_HOST_MULTIARCH}/ -type l); do \
#         if test $(dirname $(readlink $link)) != .; then \
# 	    ln -sf $I386_ROOT$(readlink $link) $link; \
# 	fi; \
#     done


###########################################
# Set up environment
#
# Customize the following to match the user's environment

# Set up user ID inside container to match your ID
ENV USER travis
ENV UID 1000
ENV GID 1000
ENV HOME /home/${USER}
ENV SHELL /bin/bash
ENV PATH /usr/lib/ccache:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin
RUN echo "${USER}:x:${UID}:${GID}::${HOME}:${SHELL}" >> /etc/passwd
RUN echo "${USER}:x:${GID}:" >> /etc/group

# Customize the run environment to your taste
# - bash prompt
# - 'ls' alias
RUN sed -i /etc/bash.bashrc \
    -e 's/^PS1=.*/PS1="\\h:\\W\\$ "/' \
    -e '$a alias ls="ls -aFs"'

# Configure sudo, passwordless for everyone
RUN echo "ALL	ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
