#!/bin/bash -e
#
# Upload packages to packagecloud.io
#
# In Travis CI, set the following environment variables:
# - PACKAGECLOUD_USER:  Travis CI user name
# - PACKAGECLOUD_TOKEN:  ** HIDDEN **  User's Travis CI token
# - PACKAGECLOUD_REPO:  Same as the GitHub repo
# - DEPLOY_BRANCH:  Only push build results for this branch
#
# The following environment variables should be set in .travis.yml:
# - CMD:  (Also may be first arg to script) Exit if not 'deb'
# - TAG:  One of amd64/i386/armhf/raspbian
#
# The following environment variables should be set by Travis CI:
# - TRAVIS_TEST_RESULT:  Exit if not '0'
# - TRAVIS_PULL_REQUEST:  Exit if not 'false'
# - TRAVIS_BRANCH:  Exit unless matches DEPLOY_BRANCH
#
# The `package_cloud` ruby gem should be installed

TAG=${1:-$TAG}

################################################
# Checks

exit_nice () { echo "No packagecloud upload:  $*" >&2; exit 0; }
error () { echo "Error:  $*" >&2; exit 1; }

test -n "PACKAGECLOUD_USER" || \
    exit_nice "PACKAGECLOUD_USER not set"
test "$CMD" = "deb" || \
    exit_nice "CMD '$CMD' != 'deb'"
test "$TRAVIS_TEST_RESULT" -eq 0 || \
    exit_nice "TRAVIS_TEST_RESULT '$TRAVIS_TEST_RESULT' != '0'"
test "$TRAVIS_PULL_REQUEST" = false || \
    exit_nice "TRAVIS_PULL_REQUEST '$TRAVIS_PULL_REQUEST' != 'false'"
test "$TRAVIS_BRANCH" = "${DEPLOY_BRANCH:-master}" || \
    exit_nice "TRAVIS_BRANCH '$TRAVIS_BRANCH' != '${DEPLOY_BRANCH:-master}'"
test -n "$TAG" || error "TAG not set"


################################################
# Set up

case $TAG in
    raspbian)  DISTRO=raspbian; exit_nice "FIXME:  not pushing Raspbian packages" ;;
    amd64|i386|armhf) DISTRO=jessie ;;
    *) error "Unknown tag '$TAG'" ;;
esac

PACKAGECLOUD_REPO=${PACKAGECLOUD_REPO:-machinekit}
PACKAGECLOUD_ARCHIVE=${PACKAGECLOUD_USER}/${PACKAGECLOUD_REPO}/debian/${DISTRO}


################################################
# Deploy

if [ "${TAG}" = "amd64" ]; then
    set -x  # Show user
    package_cloud push ${PACKAGECLOUD_ARCHIVE} ../*.dsc
else
    set -x  # Show user
fi
package_cloud push ${PACKAGECLOUD_ARCHIVE} ../*_$TAG.deb
