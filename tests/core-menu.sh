#!/bin/sh

# Offline checks for home-menu actions and cancellation.
set -eu

repo_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$repo_dir/core/menu.sh"

test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_eq() {
    [ "$1" = "$2" ] || fail "$3 (expected <$1>, got <$2>)"
}

run_action() {
    printf '%s\n' "$1" >"$test_dir/input"
    source=unchanged
    home_menu <"$test_dir/input" >"$test_dir/output" || fail "home menu rejected input <$1>"
    assert_eq "$2" "$_home_action" "home-menu action for <$1>"
    assert_eq unchanged "$source" 'home menu leaves CLI source routing to main'
}

run_action 1 search
run_action c continue
run_action history history
run_action t trending
run_action lucky lucky
run_action local files
run_action q quit

printf 'invalid\nq\n' >"$test_dir/input"
home_menu <"$test_dir/input" >"$test_dir/output"
assert_eq quit "$_home_action" 'invalid choice retries before returning an action'
grep -q 'Not a valid pick' "$test_dir/output" || fail 'invalid choice feedback'

: >"$test_dir/input"
if home_menu <"$test_dir/input" >"$test_dir/output"; then
    fail 'end of input must report menu cancellation'
fi

printf 'Core menu checks passed.\n'
