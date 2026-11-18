#!/bin/sh

# Offline checks for --json machine mode: typed errors, exit codes, escaping.
set -eu

repo_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
_test_tmp=$(mktemp -d)
trap 'rm -rf "$_test_tmp"' EXIT HUP INT TERM

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

run_json() {
    _json_out=$(env XDG_CONFIG_HOME="$_test_tmp/config" XDG_CACHE_HOME="$_test_tmp/cache" \
        "$repo_dir/tomatoplay" --json "$@" 2>"$_test_tmp/stderr") && _json_rc=0 || _json_rc=$?
}

expect_error() {
    _label=$1 _stage=$2 _fragment=$3
    shift 3
    run_json "$@"
    [ "$_json_rc" -eq 1 ] || fail "$_label: expected exit 1, got $_json_rc"
    case "$_json_out" in
        '{"ok":false'*) ;;
        *) fail "$_label: expected a JSON error object, got: $_json_out" ;;
    esac
    case "$_json_out" in
        *"\"stage\":\"$_stage\""*) ;;
        *) fail "$_label: expected stage $_stage, got: $_json_out" ;;
    esac
    case "$_json_out" in
        *"$_fragment"*) ;;
        *) fail "$_label: expected fragment $_fragment, got: $_json_out" ;;
    esac
    [ -s "$_test_tmp/stderr" ] && fail "$_label: expected empty stderr, got: $(cat "$_test_tmp/stderr")"
    [ "$(printf '%s\n' "$_json_out" | wc -l | tr -d ' ')" -eq 1 ] || fail "$_label: expected one JSON line"
}

expect_error 'missing action' '' 'missing action'
expect_error 'unknown action' '' 'unknown action: nope' nope
expect_error 'missing query' search 'missing query' search
expect_error 'unknown source' search 'unknown source: nosource' search naruto nosource
expect_error 'missing episodes args' episodes 'missing source or id' episodes
expect_error 'missing resolve args' resolve 'missing arguments' resolve
expect_error 'missing audio-modes args' audio-modes 'missing arguments' audio-modes

run_json search naruto 'bad"source'
[ "$_json_rc" -eq 1 ] || fail 'escaping: expected exit 1'
case "$_json_out" in
    *'bad\"source'*) ;;
    *) fail "escaping: quote not escaped, got: $_json_out" ;;
esac

_json_out=$(env XDG_CONFIG_HOME="$_test_tmp/config" XDG_CACHE_HOME="$_test_tmp/cache" \
    "$repo_dir/tomatoplay" --json probe </dev/null 2>"$_test_tmp/stderr") && _json_rc=0 || _json_rc=$?
[ "$_json_rc" -eq 1 ] || fail 'probe: expected exit 1 for empty input'
case "$_json_out" in
    *'"stage":"probe"'*) ;;
    *) fail "probe: expected probe stage, got: $_json_out" ;;
esac

printf 'JSON mode checks passed.\n'
