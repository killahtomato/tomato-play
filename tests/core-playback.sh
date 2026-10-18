#!/bin/sh

# Offline checks for browser playback fallback.
set -eu

repo_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$repo_dir/core/stream_resolution.sh"
. "$repo_dir/core/player.sh"
. "$repo_dir/core/playback.sh"
_test_tmp=$(mktemp -d)
trap 'rm -rf "$_test_tmp"' EXIT HUP INT TERM

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

info() { :; }

assert_eq() {
    [ "$1" = "$2" ] || fail "$3 (expected <$1>, got <$2>)"
}

mkdir -p "$_test_tmp/bin"
cat >"$_test_tmp/bin/waterfox" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >"$WATERFOX_CAPTURE"
EOF
chmod +x "$_test_tmp/bin/waterfox"
cat >"$_test_tmp/bin/mpv" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >"$PLAYER_ARGS_CAPTURE"
exit "${PLAYER_STATUS:-0}"
EOF
chmod +x "$_test_tmp/bin/mpv"
PATH="$_test_tmp/bin:$PATH"
WATERFOX_CAPTURE="$_test_tmp/waterfox-args"
PLAYER_ARGS_CAPTURE="$_test_tmp/player-args"
TOMATOPLAY_WATERFOX_PROFILE="$_test_tmp/tomato-waterfox-profile"
export PATH WATERFOX_CAPTURE PLAYER_ARGS_CAPTURE TOMATOPLAY_WATERFOX_PROFILE
source=other
video_link=https://example.invalid/episode
source_browser_fallback || fail 'Waterfox fallback should launch with a dedicated profile'
_tries=0
while [ ! -s "$WATERFOX_CAPTURE" ] && [ "$_tries" -lt 20 ]; do
    sleep 0.05
    _tries=$((_tries + 1))
done
assert_eq "$(printf '%s\n' --no-remote --profile "$TOMATOPLAY_WATERFOX_PROFILE" --kiosk --new-window "$video_link")" \
    "$(cat "$WATERFOX_CAPTURE")" 'Waterfox gets an isolated profile and kiosk URL'

source=other
player_function="$_test_tmp/bin/mpv"
player_extra_flags=
video_link=https://cdn.example/episode.m3u8
links="720 >$video_link"
_title='Test Show Episode 4'
preview=1
preview_len=30
room_role=
_hls_flags=--demuxer=lavf
_wl_flags=--save-position-on-quit=yes
_bili_proxy_flag=
launch_player
[ "$mpv_exitcode" -eq 0 ] || fail 'player adapter records a successful foreground mpv status'
grep -qx -- '--length=30' "$PLAYER_ARGS_CAPTURE" || fail 'player adapter forwards preview length'
grep -qx -- "--force-media-title=$_title" "$PLAYER_ARGS_CAPTURE" || fail 'player adapter forwards the media title'
grep -qx -- "$video_link" "$PLAYER_ARGS_CAPTURE" || fail 'player adapter forwards the selected URL'

printf 'Core playback checks passed.\n'
