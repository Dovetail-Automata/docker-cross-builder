#!/bin/bash -e

IMAGE=zultron/mk-builder-3:jessie
NAME=mk-builder

# Build: If called with args `mk-builder build [...]`, then build the image
# instead of running it, and add arguments to the `docker build` command
if test "$1" = "build"; then
    shift
    cd $(dirname $0)
    docker build -t ${IMAGE} "$@" .
    exit
fi

# Check for existing containers
EXISTING="$(docker ps -aq --filter=name=${NAME})"
if test -n "${EXISTING}"; then
    # Container exists; is it running?
    RUNNING=$(docker inspect ${EXISTING} | awk '/"Running":/ { print $2 }')
    if test "${RUNNING}" = "false,"; then
	# Remove stopped container
	echo docker rm ${EXISTING}
    elif test "${RUNNING}" = "true,"; then
	# Container already running; error
	echo "Error:  container '${NAME}' already running" >&2
	exit 1
    else
	# Something went wrong
	echo "Error:  unable to determine status of " \
	    "existing container '${EXISTING}'" >&2
	exit 1
    fi
fi

docker run --rm \
    -it --privileged \
    -u `id -u`:`id -g` \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v /dev/dri:/dev/dri \
    -v $HOME:$HOME -e HOME \
    -v $PWD:$PWD \
    -w $PWD \
    -e DISPLAY \
    -h ${NAME} --name ${NAME} \
    ${IMAGE} "$@"
