#!/bin/sh

# Offline check that the torrent player serves a selected file URL.
set -eu

repo_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$repo_dir/core/torrent_playback.sh"
. "$repo_dir/core/stream_resolution.sh"
. "$repo_dir/core/playback.sh"
_test_tmp=$(mktemp -d)
trap 'rm -rf "$_test_tmp"' EXIT HUP INT TERM

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

info() { :; }
warn() { printf '%s\n' "$*" >&2; }
_urlencode() { printf '%s' "$1" | sed 's/ /%20/g'; }
curl() { printf '200'; }
webtorrent() { printf '%s\n' "$@" >>"$_test_tmp/webtorrent-args"; }
mpv() { printf '%s\n' "$@" >"$_test_tmp/mpv-args"; }
torrent_playback() { printf 'called\n' >"$_test_tmp/torrent-route"; }

resume_dir="$_test_tmp/resume"
mkdir -p "$resume_dir"
TOMATOPLAY_TORRENT_PORT=41873
_torrent_src="$_test_tmp/sample-hash.torrent"
video_link='magnet:?xt=urn:btih:sample'
player_function=mpv
player_extra_flags=
room_role=
_room_flag=
resume_back=10

torrent_stream_one 2 'Season 1/Episode 02.mkv' 'Episode 02.mkv' '' '' >/dev/null \
    || fail 'torrent stream helper succeeds'

grep -Eq -- 'http://127\.0\.0\.1:[0-9]+/webtorrent/sample-hash/Season%201/Episode%2002\.mkv' "$_test_tmp/mpv-args" \
    || fail 'player receives the selected torrent file URL'
grep -q -- '--force-media-title=Episode 02.mkv' "$_test_tmp/mpv-args" \
    || fail 'player receives the selected file title'

source=nyaa
video_link='magnet:?xt=urn:btih:sample'
log_episode=0
player_function=mpv
anime_id=sample
anime_title='Torrent sample'
ep_no=1
mode=sub
preview=0
TOMATOPLAY_PROXY=
play_episode || fail 'episode playback routes torrent URLs to torrent playback'
[ "$(cat "$_test_tmp/torrent-route")" = called ] || fail 'magnet playback uses the torrent module'

printf 'Core torrent-playback checks passed.\n'
