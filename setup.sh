#!/usr/bin/env bash

# Set shell options.
set -eux

. common.sh

get_platform_info
check_platform


# Install required packages.
if [ ${ID} == 'ubuntu' ]; then
    sudo -v
    sudo apt-get -y install pkg-config libglib2.0-dev libgtk2.0-dev jq
fi
