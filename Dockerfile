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

# add foreign architectures
RUN dpkg --add-architecture armhf
RUN dpkg --add-architecture i386

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

# Prepare armhf build root environment
ENV ARM_ROOT=/sysroot/armhf
ENV RPI_ROOT=/sysroot/rpi
ENV ARM_HOST_MULTIARCH=arm-linux-gnueabihf
# - Install armhf cross-build toolchain and qemulator
#   For some reason, apt-get chokes without explicit `linux-libc-dev:armhf`
RUN apt-get -y install \
        crossbuild-essential-armhf \
        qemu-user-static \
        linux-libc-dev:armhf
# - Symlink armhf-arch pkg-config
RUN ln -s pkg-config /usr/bin/${ARM_HOST_MULTIARCH}-pkg-config

# Prepare i386 build root environment
ENV I386_ROOT=/sysroot/i386
ENV I386_HOST_MULTIARCH=i386-linux-gnu
# - Add cross-binutils and multilib tools
RUN apt-get install -y \
        binutils-i586-linux-gnu \
        gcc-4.9-multilib \
        g++-4.9-multilib
# - Symlink i586 binutils to i386 so ./configure can find them
RUN for i in /usr/bin/i586-linux-gnu-*; do \
        ln -s $(basename $i) $(echo $i | sed 's/i586/i386/'); \
    done
# - Symlink i386-arch pkg-config
RUN ln -s pkg-config /usr/bin/${I386_HOST_MULTIARCH}-pkg-config

###########################################
# Monkey-patches

# Add `{dh_shlibdeps,dpkg-shlibdeps} --sysroot` argument
ADD dpkg-shlibdeps.patch /tmp/
RUN cd / && \
    patch -p0 < /tmp/dpkg-shlibdeps.patch && \
    rm /tmp/dpkg-shlibdeps.patch
# Help dpkg-shlibdeps find i386 libraries
RUN mkdir -p ${I386_ROOT}/usr/lib/ && \
    ln -s ${I386_HOST_MULTIARCH} ${I386_ROOT}/usr/lib/i586-linux-gnu
RUN mkdir -p $I386_ROOT/etc && \
    cp /etc/ld.so.conf $I386_ROOT/etc/ld.so.conf


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
