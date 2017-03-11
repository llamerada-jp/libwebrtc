#!/usr/bin/env bash

get_platform_info() {
    # Get platform definition.
    if [ "$(uname)" == 'Darwin' ]; then
        readonly ID='macosx'
        readonly VERSION_ID=`sw_vers -productVersion`
        readonly ARCH='x86_64'
        readonly IS_LINUX='f'

    elif [ -e /etc/os-release ]; then
        . /etc/os-release
        readonly ARCH=`uname -p`
        readonly IS_LINUX='t'

    else
        echo 'unsupported platform'
        exit 1
    fi
}

check_platform() {
    # Check platform.
    case ${ID} in
        'macosx' ) ;;
        'ubuntu' ) ;;
        * ) echo 'unsupported platform'; exit 1 ;;
    esac
}

# Get version of release
get_chrome_version() {
    local line=`curl https://omahaproxy.appspot.com/all | grep ${CHROME_OS},stable`
    local v=`echo ${line} | cut -d ',' -f 3`
    readonly CHROME_VERSION=`echo ${v} | cut -d '.' -f 1`
}
