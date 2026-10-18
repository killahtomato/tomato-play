#!/bin/sh

# Offline checks for provider-aware candidate filtering and stable ordering.
set -eu

repo_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$repo_dir/core/result_filter.sh"

source=aniwatch

provider_episodes() {
    case "$2" in
        empty) return 0 ;;
        *) printf 'episode-key-1\t1\tEpisode 1\n' ;;
    esac
}

provider_m3u8() {
    case "$2:$4" in
        sub:sub|dub:dub|fallback-sub:sub|miruro:sub)
            printf '720 > https://cdn.example/video.m3u8\n' ;;
        *) printf '720 > https://aniwatch.example/watch/embed\n' ;;
    esac
}

_probe_playable() {
    grep -q 'https://cdn.example/'
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_eq() {
    [ "$1" = "$2" ] || fail "$3 (expected <$1>, got <$2>)"
}

input=$(printf 'aniwatch:sub\tSub result\naniwatch:dead\tDead embed\naniwatch:empty\tNo episodes\naniwatch:dub\tDub-only result\nbilibili:legal\tLegal source\nmiruro:miruro\tMiruro source\nnyaa:torrent\tTorrent source\ntpb:mirror\tTorrent mirror\nfallback-sub\tUnprefixed result')
expected=$(printf 'aniwatch:sub\tSub result\naniwatch:dub\tDub-only result\nbilibili:legal\tLegal source\nmiruro:miruro\tMiruro source\nnyaa:torrent\tTorrent source\ntpb:mirror\tTorrent mirror\nfallback-sub\tUnprefixed result')
assert_eq "$expected" "$(printf '%s\n' "$input" | filter_entries aniwatch)" \
    'filter routes prefixes, accepts sub/dub/direct-source rows, rejects dead rows, and preserves input order'

printf 'Core result-filter checks passed.\n'
