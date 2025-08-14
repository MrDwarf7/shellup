#!/bin/bash

rm -f /tmp/fetch_run

make r >/dev/null 2>&1

./build/shellup
