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
set -eux

# Setup working directory.
cd `dirname $0` || exit 1
SCRIPT_PATH=${PWD}
DEPOT_PATH=${SCRIPT_PATH}/opt/depot_tools
DEST_PATH=${SCRIPT_PATH}/opt/${ID}-${VERSION_ID}-${ARCH}
if [ ! -e ${SCRIPT_PATH}/opt ]; then
    mkdir -p ${SCRIPT_PATH}/opt
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
    git checkout refs/remotes/branch-heads/54
    git pull . refs/remotes/branch-heads/54
    cd ${DEST_PATH}
    gclient sync
else
    cd ${DEST_PATH}/src
    git checkout refs/remotes/branch-heads/54
    git pull . refs/remotes/branch-heads/54
    cd ${DEST_PATH}
    gclient sync
fi

cd ${DEST_PATH}/src
if [ ${IS_LINUX} == 't' ]; then
    ./build/install-build-deps.sh --no-prompt
fi
gn gen out/Default --args='is_debug=false'
ninja -C out/Default

# Make archive
rm -rf ${DEST_PATH}/lib
rm -rf ${DEST_PATH}/include
mkdir -p ${DEST_PATH}/lib
mkdir -p ${DEST_PATH}/include
OUT_PATH=${DEST_PATH}/src/out/Default
case ${ID} in
    'macosx' )
        NINJA_FILE=${OUT_PATH}/obj/webrtc/examples/AppRTCDemo_executable.ninja
        TARGET='obj/webrtc/examples/AppRTCDemo_executable/AppRTCDemo:'
        ;;
    'ubuntu' )
        NINJA_FILE=${OUT_PATH}/obj/webrtc/examples/peerconnection_client.ninja
        TARGET='peerconnection_client:'
        ;;
    * ) echo 'unsupported platform'; exit 1 ;;
esac

cd ${OUT_PATH}
objs=''
for obj in `cat ${NINJA_FILE} | grep ${TARGET}`
do
    if [[ ${obj} =~ 'obj/webrtc/examples' ]]; then
        continue
    elif [[ ${obj} =~ \.o$ ]]; then
        objs="${objs} ${obj}"
    elif [[ ${obj} =~ \.a$ ]]; then
        cp ${obj} ${DEST_PATH}/lib/
    fi
done
ar cr ${DEST_PATH}/lib/libprocesswarp_webrtc.a ${objs}

# Rename libdl to libopenmax_dl, because libdl is used to library for Dynamic Link.
mv ${DEST_PATH}/lib/libdl.a ${DEST_PATH}/lib/libopenmax_dl.a

cd ${DEST_PATH}/src
find webrtc -name '*.h' -exec rsync -R {} ${DEST_PATH}/include/ \;
