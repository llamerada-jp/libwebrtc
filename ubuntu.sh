
set -e
set -u
set -x

sudo -v
sudo apt-get -y install pkg-config libglib2.0-dev libgtk2.0-dev

. /etc/lsb-release
START_PATH=${PWD}
DEST_PATH=${PWD}/../webrtc-${DISTRIB_CODENAME}-`uname -p`
DEPOT_PATH=${PWD}/../depot_tools

# checkout depot_tools
if [ ! -e ${DEPOT_PATH} ]; then
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git ${DEPOT_PATH}
else
    cd ${DEPOT_PATH}
    git pull
fi

# set PATH
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
./build/install-build-deps.sh --no-prompt
gn gen out/Default --args='is_debug=false'
ninja -C out/Default
