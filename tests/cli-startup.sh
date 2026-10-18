#!/bin/sh

# Verify module loading both from the checkout and the installer layout.
set -eu

repo_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
_test_tmp=$(mktemp -d)
trap 'rm -rf "$_test_tmp"' EXIT HUP INT TERM

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

run_cli() {
    _cli_path=$1
    shift
    env \
        XDG_CONFIG_HOME="$_test_tmp/config" \
        XDG_STATE_HOME="$_test_tmp/state" \
        XDG_CACHE_HOME="$_test_tmp/cache" \
        TOMATOPLAY_PLAYER=debug \
        TOMATOPLAY_MENU=dmenu \
        TOMATOPLAY_LOG=0 \
        "$_cli_path" "$@"
}

_checkout_version=$(run_cli "$repo_dir/tomatoplay" --version) || fail 'checkout CLI starts and loads modules'
[ -n "$_checkout_version" ] || fail 'checkout CLI prints its version'

_prefix="$_test_tmp/prefix"
(cd "$repo_dir" && PREFIX="$_prefix" ./install.sh >/dev/null) || fail 'installer populates a temporary prefix'
[ -r "$_prefix/lib/tomato-play/providers/dispatch.sh" ] || fail 'installed provider modules exist'
[ -r "$_prefix/lib/tomato-play/core/room.sh" ] || fail 'installed room module exists'
[ -r "$_prefix/lib/tomato-play/core/stream_resolution.sh" ] || fail 'installed stream module exists'
[ -r "$_prefix/lib/tomato-play/core/torrent_playback.sh" ] || fail 'installed torrent module exists'
[ -r "$_prefix/lib/tomato-play/core/player.sh" ] || fail 'installed player module exists'
_installed_version=$(run_cli "$_prefix/bin/tomatoplay" --version) || fail 'installed CLI resolves modules from lib path'
[ "$_installed_version" = "$_checkout_version" ] || fail 'checkout and installed CLI versions match'

mkdir -p "$_test_tmp/join-room"
_join_status=0
_join_output=$(run_cli "$repo_dir/tomatoplay" --join "$_test_tmp/join-room" 2>&1) || _join_status=$?
[ "$_join_status" -eq 1 ] || fail 'guest CLI reports a missing host session'
case "$_join_output" in
    *'No room session yet — start the host first'*) ;;
    *) fail "guest CLI reports the missing room state clearly (got: $_join_output)" ;;
esac

printf 'CLI startup checks passed.\n'
