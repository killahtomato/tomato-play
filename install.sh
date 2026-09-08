#!/bin/sh
# Tomato Play installer
# Installs `tomatoplay` (and `tp` alias) into PREFIX/bin
set -e

PREFIX="${PREFIX:-/usr/local}"

if [ ! -f ./tomatoplay ]; then
    echo "Error: tomatoplay not found in current directory" >&2
    exit 1
fi

install -Dm755 ./tomatoplay "${PREFIX}/bin/tomatoplay"
ln -sf tomatoplay "${PREFIX}/bin/tp"

echo "Installed to ${PREFIX}/bin/tomatoplay (and tp)"
