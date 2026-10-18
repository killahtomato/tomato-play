#!/bin/sh

# Offline checks for watch-room setup and guest attachment.
set -eu

repo_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$repo_dir/core/room.sh"
_test_tmp=$(mktemp -d)
trap 'rm -rf "$_test_tmp"' EXIT HUP INT TERM

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_eq() {
    [ "$1" = "$2" ] || fail "$3 (expected <$1>, got <$2>)"
}

assert_status() {
    _expected=$1
    shift
    _actual=0
    "$@" || _actual=$?
    [ "$_actual" -eq "$_expected" ] || fail "status for $* (expected $_expected, got $_actual)"
}

room_role=host
room_dir="$_test_tmp/host-room"
hist_dir="$_test_tmp/state"
_room_flag=
room_bootstrap || fail 'host room setup succeeds'
assert_eq "--script=$room_dir/tp-room-host.lua" "$_room_flag" 'host loads its sync script'
assert_eq "$room_dir" "$TP_ROOM_DIR" 'room directory is passed to mpv scripts'
[ -s "$room_dir/tp-room-host.lua" ] || fail 'host Lua script is generated'
[ -s "$room_dir/tp-room-guest.lua" ] || fail 'guest Lua script is generated'
grep -Fq "mp.add_periodic_timer(2, tick)" "$room_dir/tp-room-host.lua" || fail 'host publishes state every two seconds'
grep -Fq "mp.add_periodic_timer(1, tick)" "$room_dir/tp-room-guest.lua" || fail 'guest follows state every second'
printf '%s\n' '--preserve-existing-script' >"$room_dir/tp-room-host.lua"
room_bootstrap || fail 'repeat room setup succeeds'
grep -Fq -- '--preserve-existing-script' "$room_dir/tp-room-host.lua" || fail 'existing room scripts are preserved'

room_role=guest
room_dir=
hist_dir="$_test_tmp/default-state"
room_bootstrap || fail 'guest setup uses its default room directory'
assert_eq "$hist_dir/room" "$room_dir" 'empty room directory defaults under state path'
assert_eq "--script=$room_dir/tp-room-guest.lua" "$_room_flag" 'guest loads its sync script'
assert_status 2 room_join_prepare

mkdir -p "$_test_tmp/shared"
touch "$_test_tmp/shared/episode.mkv"
printf '%s\n10\nfalse\n' "$_test_tmp/shared/episode.mkv" >"$room_dir/hoststate"
room_join_prepare || fail 'guest attaches when host state and shared file exist'
assert_eq "$_test_tmp/shared/episode.mkv" "$local_path" 'guest selects the host file path'

printf '%s\n' "$_test_tmp/not-visible.mkv" >"$room_dir/hoststate"
assert_status 3 room_join_prepare

printf 'not a directory\n' >"$_test_tmp/blocked-room"
room_dir="$_test_tmp/blocked-room/child"
assert_status 1 room_join_prepare

printf 'Core room checks passed.\n'
