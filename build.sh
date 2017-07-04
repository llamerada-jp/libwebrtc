#!/usr/bin/env bash

# Set shell options.
set -eux

readonly GITHUB_URL='https://api.github.com'
readonly GITHUB_OWNER='llamerada-jp'
readonly GITHUB_REPO='libwebrtc'

readonly GITHUB_PATH="${GITHUB_URL}/repos/${GITHUB_OWNER}/${GITHUB_REPO}"

# Get depot_tools.
get_depot_tools() {
    if [ ! -e ${DEPOT_PATH} ]; then
	git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git ${DEPOT_PATH}
    else
	cd ${DEPOT_PATH}
	git pull
    fi
}

# Get rpi_tools.
get_rpi_tools() {
    if [ ! -e ${RPI_PATH} ]; then
	git clone https://github.com/raspberrypi/tools.git ${RPI_PATH}
    else
	cd ${RPI_PATH}
	git pull
    fi

    # Set PATH.
    export PATH=${RPI_PATH}/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/bin:${PATH}
}

# Get stable version number of chrome.
set_chrome_version() {
    case ${ID} in
	'macos' ) local os='mac' ;;
	'raspbian' ) local os='linux' ;;
	'ubuntu' ) local os='linux' ;;
    esac

    local line=`curl https://omahaproxy.appspot.com/all | grep ${os},stable`
    local v=`echo ${line} | cut -d ',' -f 3`
    readonly CHROME_VERSION=`echo ${v} | cut -d '.' -f 1`
}

# Get platform definition.
set_platform_info() {
    if [ "$(uname)" == 'Darwin' ]; then
        readonly ID='macos'
        readonly VERSION_ID=`sw_vers -productVersion`
        readonly ARCH='x86_64'
        readonly IS_LINUX='f'

    elif [ "${TARGET}" == 'rpi' ]; then
	readonly ID='raspbian'
	readonly VERSION_ID='wheezy'
	readonly ARCH='arm'
	readonly IS_LINUX='true'

    elif [ -e /etc/os-release ]; then
        . /etc/os-release
	if [ "${TARGET}" == 'x86' ]; then
	    readonly ARCH='x86'
	else
            readonly ARCH=`uname -p`
	fi
        readonly IS_LINUX='true'

    else
        echo 'unsupported platform'
        exit 1
    fi

    # Set paths.
    cd $1
    SCRIPT_PATH=${PWD}
    DEPOT_PATH=${SCRIPT_PATH}/opt/depot_tools
    DEST_PATH=${SCRIPT_PATH}/opt/${ID}-${VERSION_ID}-${ARCH}
    # Set paths for raspbian.
    if [ "${ID}" == 'raspbian' ]; then
	RPI_PATH=${SCRIPT_PATH}/opt/rpi_tools
	RPI_ROOT=${SCRIPT_PATH}/opt/rpi_root
    fi

}

# Set arvhive infos.
set_archive_info() {
    if [ "${IS_LINUX}" != 'true' ]; then
	readonly ARCHIVE_FILE=${DEST_PATH}/libwebrtc-${ID}-${CHROME_VERSION}.zip
	readonly ARCHIVE_TYPE='zip'
    else
	readonly ARCHIVE_FILE=${DEST_PATH}/libwebrtc-${ID}-${VERSION_ID}-${ARCH}-${CHROME_VERSION}.tar.gz
	readonly ARCHIVE_TYPE='gzip'
    fi
}

set_build_info() {
    OUT_PATH=${DEST_PATH}/src/out/Default

    case ${ID} in
	'macos' )
	    if [ `expr ${CHROME_VERSION}` -ge 57 ]; then
		readonly NINJA_FILE=${OUT_PATH}/obj/webrtc/examples/AppRTCMobile_executable.ninja
		readonly NINJA_TARGET='obj/webrtc/examples/AppRTCMobile_executable/AppRTCMobile'
		readonly BUILD_TARGET='AppRTCMobile'
	    else
		readonly NINJA_FILE=${OUT_PATH}/obj/webrtc/examples/AppRTCDemo_executable.ninja
		readonly NINJA_TARGET='obj/webrtc/examples/AppRTCDemo_executable/AppRTCDemo:'
		readonly BUILD_TARGET='AppRTCDemo'
	    fi
            ;;
	'raspbian' )
	    readonly NINJA_FILE=${OUT_PATH}/obj/webrtc/examples/peerconnection_client.ninja
	    readonly NINJA_TARGET='peerconnection_client:'
	    readonly BUILD_TARGET='peerconnection_client'
	    ;;
	'ubuntu' )
            readonly NINJA_FILE=${OUT_PATH}/obj/webrtc/examples/peerconnection_client.ninja
            readonly NINJA_TARGET='peerconnection_client:'
	    readonly BUILD_TARGET='peerconnection_client'
            ;;
	* ) echo 'unsupported platform'; exit 1 ;;
    esac
}

setup() {
    if [ ! -e ${SCRIPT_PATH}/opt ]; then
	mkdir -p ${SCRIPT_PATH}/opt
    fi

    get_depot_tools

    case "${ID}" in
	'macos'   ) setup_macos ;;
	'raspbian' ) setup_raspbian ;;
	'ubuntu'   ) setup_ubuntu ;;
    esac
}

setup_macos() {
    brew install jq
}

setup_raspbian() {
    sudo -v
    sudo apt-get -y install qemu-user-static debootstrap jq

    # Build cross compile environment.
    get_rpi_tools

    sudo debootstrap --arch armhf --foreign --include=g++,libasound2-dev,libpulse-dev,libudev-dev,libexpat1-dev,libnss3-dev,libgtk2.0-dev ${VERSION_ID} ${RPI_ROOT}
    sudo cp /usr/bin/qemu-arm-static ${RPI_ROOT}/usr/bin/
    sudo chroot ${RPI_ROOT} /debootstrap/debootstrap --second-stage
    find ${RPI_ROOT}/usr/lib/arm-linux-gnueabihf -lname '/*' -printf '%p %l\n' | while read link target
    do
	sudo ln -snfv "../../..${target}" "${link}"
    done
    find ${RPI_ROOT}/usr/lib/arm-linux-gnueabihf/pkgconfig -printf "%f\n" | while read target
    do
	sudo ln -snfv "../../lib/arm-linux-gnueabihf/pkgconfig/${target}" ${RPI_ROOT}/usr/share/pkgconfig/${target}
    done
}

setup_ubuntu() {
    sudo -v
    sudo apt-get -y install pkg-config libglib2.0-dev libgtk2.0-dev jq
}

build() {
    if [ "${ID}" == 'raspbian' ]; then
	export GYP_CROSSCOMPILE=1
	export GYP_DEFINES="OS=linux target_arch=arm arm_version=7 arm_use_neon=1 arm_float_abi=hard clang=0 include_tests=0 sysroot=${RPI_ROOT}"
	export GYP_GENERATOR_OUTPUT='arm'

    elif [ "${IS_LINUX}" == 'true' -a "${ARCH}" == 'x86' ]; then
	export GYP_DEFINES='target_arch=ia32'
    fi

    # First time build.
    if [ ! -e ${DEST_PATH} ]; then
	mkdir -p ${DEST_PATH}
	cd ${DEST_PATH}
	fetch --nohooks webrtc
	gclient sync --with_branch_heads
	cd ${DEST_PATH}/src

	if [ "${ID}" == 'raspbian' ]; then
	    ./build/install-build-deps.sh --arm --no-prompt
	elif [ "${IS_LINUX}" == 'true' ]; then
	    ./build/install-build-deps.sh --no-prompt
	fi
	git fetch
    fi

    # Change branch for stable chrome version.
    cd ${DEST_PATH}/src
    git checkout master
    git pull
    git checkout -B "local_work_${CHROME_VERSION}" "branch-heads/${CHROME_VERSION}"

    # Build main.
    gclient sync --jobs 16
    gn gen out/Default --args="is_debug=${ENABLE_DEBUG}"
    ninja -C out/Default ${BUILD_TARGET}
}

# Make archive
build_archive() {
    rm -rf ${DEST_PATH}/lib
    rm -rf ${DEST_PATH}/include
    mkdir -p ${DEST_PATH}/lib
    mkdir -p ${DEST_PATH}/include
    OUT_PATH=${DEST_PATH}/src/out/Default

    cd ${OUT_PATH}
    objs=''
    for obj in `cat ${NINJA_FILE} | grep ${NINJA_TARGET}`
    do
	if [[ ${obj} =~ 'obj/webrtc/examples' ]]; then
            continue
	elif [[ ${obj} =~ \.o$ ]]; then
            objs="${objs} ${obj}"
	elif [[ ${obj} =~ \.a$ ]]; then
            cp ${obj} ${DEST_PATH}/lib/
	fi
    done
    ar cr ${DEST_PATH}/lib/libwebrtc.a ${objs}

    # Rename libdl to libopenmax_dl, because libdl is used to library for Dynamic Link.
    mv ${DEST_PATH}/lib/libdl.a ${DEST_PATH}/lib/libopenmax_dl.a

    cd ${DEST_PATH}/src
    find webrtc -name '*.h' -exec rsync -R {} ${DEST_PATH}/include/ \;

    case "${ARCHIVE_TYPE}" in
	'zip'  )
	    cd ${DEST_PATH}
	    zip -r ${ARCHIVE_FILE} lib include
	    ;;
	'gzip' )
	    cd ${DEST_PATH}
	    tar -czf ${ARCHIVE_FILE} lib include
	    ;;
    esac
}

upload() {
    local upload_url=`curl ${GITHUB_PATH}/releases | jq -r "map(select(.body == \"${CHROME_VERSION}\")) | .[].upload_url"`
    if [ ${GITHUB_PASSWORD:-''} == '' ]; then
	read -sp "Password for github: " GITHUB_PASSWORD
    fi

    if [ "${upload_url}" = '' ]; then
	local release_json=`cat << EOS
{
  "tag_name": "v${CHROME_VERSION}",
  "target_commitish": "master",
  "name": "v${CHROME_VERSION}",
  "body": "${CHROME_VERSION}",
  "draft": false,
  "prerelease": false
}
EOS
`
	upload_url=`curl -v -u "${GITHUB_OWNER}:${GITHUB_PASSWORD}" -H 'Content-type: application/json' -d "${release_json}" "${GITHUB_PATH}/releases" | jq -r ".upload_url"`
    fi

    cd ${DEST_PATH}
    upload_url=${upload_url%assets*}
    upload_url="${upload_url}assets?name=$(basename $ARCHIVE_FILE)"
    curl -v -u "${GITHUB_OWNER}:${GITHUB_PASSWORD}" -H "Content-Type: $(file -b --mime-type $ARCHIVE_FILE)" --data-binary @${ARCHIVE_FILE} ${upload_url}
}

show_usage() {
    echo "Usage: $1 [-Bhrsu]" 1>&2
    echo "  -B : Disable build sequence." 1>&2
    echo "  -h : Show help." 1>&2
    echo "  -s : Setup build environment." 1>&2
    echo "  -t : Set target." 1>&2
    echo "    rpi : Raspbian." 1>&2
    echo "    x86 : Linux with x86 architecture." 1>&2
    echo "  -u : Upload archive to github release." 1>&2
}

# Default options.
TARGET=''
ENABLE_SETUP='false'
ENABLE_BUILD='true'
ENABLE_UPLOAD='false'
ENABLE_DEBUG='false'

# Decode options.
while getopts Bdhst:u OPT
do
    case $OPT in
	B)  ENABLE_BUILD='false'
	    ;;
	d)  ENABLE_DEBUG='true'
	    ;;
	h)  show_usage $0
	    exit 0
	    ;;
        s)  ENABLE_SETUP='true'
            ;;
	t)  TARGET=$OPTARG
	    ;;
        u)  ENABLE_UPLOAD='true'
            ;;
        \?) show_usage $0
	    exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

# Set environment values.
set_platform_info `dirname $0`
set_chrome_version
set_archive_info
set_build_info

# Setup.
if [ "${ENABLE_SETUP}" == 'true' ]; then
    setup
fi

# Set PATH.
export PATH=${DEPOT_PATH}:${PATH}

# Build.
if [ "${ENABLE_BUILD}" == 'true' ]; then
    build
    build_archive
fi

# Upload.
if [ "${ENABLE_UPLOAD}" == 'true' ]; then
    upload
fi
