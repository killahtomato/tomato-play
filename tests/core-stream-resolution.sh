#!/bin/sh

# Offline checks for stream reachability and provider-specific playback setup.
set -eu

repo_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$repo_dir/core/stream_resolution.sh"
_test_tmp=$(mktemp -d)
trap 'rm -rf "$_test_tmp"' EXIT HUP INT TERM
MOCK_YTDLP_CAPTURE="$_test_tmp/yt-dlp-args"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

die() {
    printf '%s\n' "$*" >&2
    return 1
}

info() { :; }

assert_eq() {
    [ "$1" = "$2" ] || fail "$3 (expected <$1>, got <$2>)"
}

tp_curl_status() {
    printf '%s\n' "$@" >"$_test_tmp/probe-args"
    printf '%s\n' "${MOCK_HTTP_STATUS:-200}"
}

source=other
agent='Test Browser'
MOCK_HTTP_STATUS=200
_stream_alive https://cdn.example/video.mp4 || fail 'healthy stream passes reachability probe'
assert_eq 'https://cdn.example/video.mp4' "$(cat "$_test_tmp/probe-args")" 'ordinary probe delegates URL to shared curl helper'

source=animegg
_stream_alive https://cdn.example/video.mp4 || fail 'AnimeGG stream passes reachability probe'
assert_eq '--range
0-0
https://cdn.example/video.mp4' "$(cat "$_test_tmp/probe-args")" 'AnimeGG probe retains range request'

source=miruro
_stream_alive https://cdn.example/video.m3u8 https://www.miruro.to/ https://www.miruro.to || fail 'Miruro stream passes reachability probe'
assert_eq '-e
https://www.miruro.to/
-H
Origin: https://www.miruro.to
https://cdn.example/video.m3u8' "$(cat "$_test_tmp/probe-args")" 'Miruro probe passes Referer and Origin to shared curl helper'

MOCK_HTTP_STATUS=503
if _stream_alive https://cdn.example/video.mp4; then
    fail 'server error is rejected by stream reachability policy'
fi

yt-dlp() {
    printf '%s\n' "$@" >"$MOCK_YTDLP_CAPTURE"
    [ "${MOCK_YTDLP_STATUS:-0}" -eq 0 ] && return 0
    printf '%s\n' "${MOCK_YTDLP_ERROR:-yt-dlp failed}" >&2
    return "$MOCK_YTDLP_STATUS"
}

source=other
player_function=mpv
video_link=https://example.invalid/video
MOCK_YTDLP_STATUS=0
TOMATOPLAY_PROXY=
bilibili_playback_preflight
[ ! -e "$MOCK_YTDLP_CAPTURE" ] || fail 'non-Bilibili source skips preflight'

source=bilibili
TOMATOPLAY_PROXY=socks5h://127.0.0.1:1080
bilibili_playback_preflight || fail 'successful Bilibili preflight'
assert_eq "--proxy
socks5h://127.0.0.1:1080
--simulate
--no-warnings
--no-playlist
https://example.invalid/video" "$(cat "$MOCK_YTDLP_CAPTURE")" 'proxy and URL are passed to yt-dlp'

MOCK_YTDLP_STATUS=1
MOCK_YTDLP_ERROR='ERROR: This video is not available in your country due to copyright restrictions.'
_diagnostic=$(bilibili_playback_preflight 2>&1) && fail 'geo restriction preflight should fail'
case "$_diagnostic" in
    *'geo-restricted for this IP'*'TOMATOPLAY_PROXY'*) ;;
    *) fail "clear geo restriction diagnostic (got: $_diagnostic)" ;;
esac

MOCK_YTDLP_ERROR='ERROR: [BiliBiliBangumi] 97919: Unable to download webpage: HTTP Error 412: Precondition Failed (caused by <HTTPError 412: Precondition Failed>)'
_diagnostic=$(bilibili_playback_preflight 2>&1) && fail 'HTTP 412 preflight should fail'
case "$_diagnostic" in
    *'HTTP 412: Precondition Failed'*'anti-bot'*'not proof of a geo-block'*) ;;
    *) fail "human-readable HTTP 412 diagnostic (got: $_diagnostic)" ;;
esac

for _provider in aniwatch bilibili miruro youtube files; do
    provider_browser_fallback_allowed "$_provider" || fail "browser fallback should allow $_provider"
done
for _provider in nyaa tpb; do
    if provider_browser_fallback_allowed "$_provider"; then
        fail "browser fallback must exclude torrent source $_provider"
    fi
done

assert_eq "$(printf 'https://www.miruro.to/\nhttps://www.miruro.tv/')" \
    "$(miruro_referrer_candidates)" 'Miruro defaults try both site domains'
TOMATOPLAY_MIRURO_REFERER=https://custom.miruro.example/
assert_eq "$(printf 'https://custom.miruro.example/\nhttps://www.miruro.to/\nhttps://www.miruro.tv/')" \
    "$(miruro_referrer_candidates)" 'custom Miruro referrer is tried with both defaults'
assert_eq 'https://www.miruro.to/watch/20/naruto-shippuden/12' \
    "$(miruro_watch_url 20 'Naruto Shippuden' 12)" 'Miruro browser URL uses the anime watch route'
assert_eq 'https://www.miruro.tv/watch/20/naruto/1' \
    "$(miruro_watch_url 20 Naruto 1 https://www.miruro.tv/)" 'Miruro browser URL supports alternate site domain'

printf 'Core stream-resolution checks passed.\n'
