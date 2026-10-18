#!/bin/sh
# Tomato Play installer
# Installs `tomatoplay`, provider modules, and the `tp` alias under PREFIX
set -e

PREFIX="${PREFIX:-/usr/local}"

if [ ! -f ./tomatoplay ]; then
    echo "Error: tomatoplay not found in current directory" >&2
    exit 1
fi

install -Dm755 ./tomatoplay "${PREFIX}/bin/tomatoplay"
install -d "${PREFIX}/lib/tomato-play/providers"
install -m644 ./providers/*.sh "${PREFIX}/lib/tomato-play/providers/"
install -d "${PREFIX}/lib/tomato-play/core"
install -m644 ./core/*.sh "${PREFIX}/lib/tomato-play/core/"
ln -sf tomatoplay "${PREFIX}/bin/tp"

if [ -d ./completions ]; then
    for d in \
        "${PREFIX}/share/bash-completion/completions" \
        "${PREFIX}/share/zsh/site-functions" \
        "${PREFIX}/share/fish/vendor_completions.d"; do
        mkdir -p "$d"
    done
    install -m644 ./completions/tomato-play.bash "${PREFIX}/share/bash-completion/completions/tp"
    install -m644 ./completions/_tomatoplay "${PREFIX}/share/zsh/site-functions/_tp"
    install -m644 ./completions/tomato-play.fish "${PREFIX}/share/fish/vendor_completions.d/tp.fish"
fi

echo "Installed to ${PREFIX}/bin/tomatoplay (and tp)"
[ -d ./completions ] && echo "Completions installed for bash, zsh, and fish"
