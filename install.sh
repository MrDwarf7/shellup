#!/bin/env bash

set -e

export BUILD_TYPE=release # release | debug
export VERBOSE=1          # 1 | 0
export INSTALL_PATH=/usr/local/bin

# Set manualy to make sure lol
BUILD_TYPE=release VERBOSE=1 sudo make install
return $?
