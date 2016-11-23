#!/usr/bin/env bash

# Get platform definition.
if [ "$(uname)" == 'Darwin' ]; then
    ID='macosx'
    VERSION_ID=`sw_vers -productVersion`
    ARCH='x86_64'
    IS_LINUX='f'

elif [ -e /etc/os-release ]; then
    . /etc/os-release
    ARCH=`uname -p`
    IS_LINUX='t'

else
    echo 'unsupported platform'
    exit 1
fi

# Check platform.
case ${ID} in
    'macosx' ) ;;
    'ubuntu' ) ;;
    * ) echo 'unsupported platform'; exit 1 ;;
esac

# Set shell options.
set -e
set -u
set -x

# Setup working directory.
cd `dirname $0` || exit 1
SCRIPT_PATH=${PWD}
DEPOT_PATH=${SCRIPT_PATH}/opt/depot_tools
DEST_PATH=${SCRIPT_PATH}/opt/${ID}-${VERSION_ID}-${ARCH}
if [ ! -e ${SCRIPT_PATH}/opt ]; then
    mkdir -p ${SCRIPT_PATH}/opt
fi

# Install required packages.
if [ ${ID} == 'ubuntu' ]; then
    sudo -v
    sudo apt-get -y install pkg-config libglib2.0-dev libgtk2.0-dev
fi

# Checkout depot_tools.
if [ ! -e ${DEPOT_PATH} ]; then
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git ${DEPOT_PATH}
else
    cd ${DEPOT_PATH}
    git pull
fi

# Set PATH.
export PATH=${DEPOT_PATH}:${PATH}

if [ ! -e ${DEST_PATH} ]; then
    mkdir -p ${DEST_PATH}
    cd ${DEST_PATH}
    fetch --nohooks webrtc
    gclient sync
    cd ${DEST_PATH}/src
    git checkout branch-heads/54
    git pull . branch-heads/54
    cd ${DEST_PATH}
    gclient sync
else
    cd ${DEST_PATH}/src
    git checkout branch-heads/54
    git pull . branch-heads/54
    cd ${DEST_PATH}
    gclient sync
fi

cd ${DEST_PATH}/src
if [ ${IS_LINUX} == 't' ]; then
    ./build/install-build-deps.sh --no-prompt
fi
gn gen out/Default --args='is_debug=false'
ninja -C out/Default
