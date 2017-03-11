#!/usr/bin/env bash

# Set shell options.
set -eux

. common.sh

get_platform_info
check_platform

case ${ID} in
    'macosx' ) readonly CHROME_OS='mac' ;;
    'ubuntu' ) readonly CHROME_OS='linux' ;;
esac

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
    gclient sync --with_branch_heads
    cd ${DEST_PATH}/src
    git fetch
fi

get_chrome_version

cd ${DEST_PATH}/src
git checkout -B local_work "branch-heads/${CHROME_VERSION}"
gclient sync --jobs 16

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
