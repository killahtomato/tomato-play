#!/bin/sh

# Offline checks for history persistence, display, stats, and continuation.
set -eu

repo_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$repo_dir/core/history.sh"

test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
histfile="$test_dir/history"
resume_dir="$test_dir/resume"
source=aniwatch
mkdir -p "$resume_dir"
: >"$histfile"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_eq() {
    [ "$1" = "$2" ] || fail "$3 (expected <$1>, got <$2>)"
}

anime_id='anime-1'
ep_no=5
anime_title='First Show'
update_history "$histfile" "$source" "$anime_id" "$ep_no" "$anime_title"
assert_eq "$(printf '5\taniwatch:anime-1\tFirst Show')" "$(cat "$histfile")" 'new history row stores its provider'

ep_no=8
anime_title='Changed & Show'
update_history "$histfile" "$source" "$anime_id" "$ep_no" "$anime_title"
assert_eq "$(printf '8\taniwatch:anime-1\tChanged & Show')" "$(cat "$histfile")" 'existing history row update'

printf '3\tlegacy-id\tLegacy Show\n' >"$histfile"
anime_id='legacy-id'
ep_no=4
anime_title='Legacy Show'
update_history "$histfile" "$source" "$anime_id" "$ep_no" "$anime_title"
assert_eq "$(printf '4\taniwatch:legacy-id\tLegacy Show')" "$(cat "$histfile")" \
    'legacy unprefixed history is upgraded under its original source'

_explicit_histfile="$test_dir/explicit-history"
: >"$_explicit_histfile"
update_history "$_explicit_histfile" tpb explicit-id 3 'Explicit State Show'
assert_eq "$(printf '3\texplicit-id\tExplicit State Show')" "$(cat "$_explicit_histfile")" \
    'history writer uses only the path and playback fields passed to it'

printf '5\tanime-1\tFirst Show\n12\tanime-2\tSecond Show\n' >"$histfile"
expected_view=$(printf '1. First Show (episode 5)\n2. Second Show (episode 12)')
assert_eq "$expected_view" "$(history_view "$histfile")" 'history display'
stats=$(garden_stats "$histfile")
printf '%s\n' "$stats" | grep -q 'Series in the garden : 2' || fail 'history series count'
printf '%s\n' "$stats" | grep -q 'Episodes logged       : 17' || fail 'history episode total'
printf '%s\n' "$stats" | grep -q 'Approx. time watched  : 6.8 h' || fail 'history time estimate'
printf '%s\n' "$stats" | grep -q 'Marathon champ        : Second Show (episode 12)' || fail 'history marathon champ'

info() { :; }
histfile="$test_dir/missing-history"
history_view "$histfile" >/dev/null
empty_stats=$(garden_stats "$histfile")
printf '%s\n' "$empty_stats" | grep -q "garden's still empty" || fail 'empty history stats'

provider_episodes() {
    case "$1:$2" in
        aniwatch:anime-1) printf 'provider-key-6\t6\tEpisode 6\nprovider-key-7\t7\tEpisode 7\n' ;;
        miruro:20) printf '1\t1\tEpisode 1\n2\t2\tEpisode 2\n' ;;
        *) return 1 ;;
    esac
}
anime_id='anime-1'
anime_title='Resume Show'
ep_no=6
source=anidb
process_hist_entry "$resume_dir" "$ep_no" anime-1 "$anime_title" >"$test_dir/next-entry"
next_entry=$(cat "$test_dir/next-entry")
assert_eq "$(printf 'aniwatch:anime-1\tResume Show - episode 7')" "$next_entry" 'continue advances legacy unprefixed history through aniwatch'
assert_eq 'anidb' "$source" 'history-row lookup leaves the active source unchanged'

ep_no=6
resume_key=$(printf '%s-%s' "$anime_id" "$ep_no" | tr -c '[:alnum:]' '_')
mkdir -p "$resume_dir/$resume_key"
: >"$resume_dir/$resume_key/watch_later"
process_hist_entry "$resume_dir" "$ep_no" aniwatch:anime-1 "$anime_title" >"$test_dir/resumed-entry"
resumed_entry=$(cat "$test_dir/resumed-entry")
assert_eq "$(printf 'aniwatch:anime-1\tResume Show - episode 6')" "$resumed_entry" 'resume position keeps the current episode'

anime_id='miruro:20'
anime_title='Miruro Show'
ep_no=1
process_hist_entry "$resume_dir" "$ep_no" "$anime_id" "$anime_title" >"$test_dir/miruro-entry"
assert_eq "$(printf 'miruro:20\tMiruro Show - episode 2')" "$(cat "$test_dir/miruro-entry")" \
    'continue keeps the Miruro source and advances its episode'
assert_eq 'anidb' "$source" 'Miruro history lookup leaves the active source unchanged'

printf 'Core history checks passed.\n'
