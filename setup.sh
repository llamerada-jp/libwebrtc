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

# Install required packages.
if [ ${ID} == 'ubuntu' ]; then
    sudo -v
    sudo apt-get -y install pkg-config libglib2.0-dev libgtk2.0-dev
fi
