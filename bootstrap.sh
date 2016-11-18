#!/usr/bin/env bash

if [ "$(uname)" == 'Darwin' ]; then
    sh ./macosx.sh

elif [ "$(expr substr $(uname -s) 1 5)" == 'Linux' ]; then
    if [ -e /etc/lsb-release ]; then
	bash ./ubuntu.sh
    fi
fi
