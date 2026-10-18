#!/bin/sh

# Offline checks for stable menu selection values and provider routing.
set -eu

repo_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$repo_dir/core/selection.sh"

_test_dir=$(mktemp -d)
trap 'rm -rf "$_test_dir"' EXIT HUP INT TERM
menu_extra_flags=
menu_multi_flag=-m
menu() {
    printf '%s|%s|%s|%s\n' "$1" "$2" "$3" "$4" >"$_test_dir/menu-args"
    while IFS= read -r _menu_row; do
        _menu_id=${_menu_row%% *}
        case " $_test_selected_ids " in
            *" $_menu_id "*) printf '%s\n' "$_menu_row" ;;
        esac
    done
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_eq() {
    [ "$1" = "$2" ] || fail "$3 (expected <$1>, got <$2>)"
}

assert_eq "$(printf 'payload-1\tSingle title')" \
    "$(printf 'row-1\tpayload-1\tSingle title\n' | nth 'Pick: ' '' '' '')" \
    'single row returns its payload and label without prompting'

_test_selected_ids='2 4'
_selection_rows=$(printf 'key-a\tpayload-a\tFirst title\nkey-b\tpayload-b\tSecond title\nkey-c\tpayload-c\tThird title\nkey-d\tpayload-d\tFourth title')
_selected=$(printf '%s\n' "$_selection_rows" | nth 'Pick: ' '-m' '' '')
assert_eq "$(printf 'payload-b\tSecond title\npayload-d\tFourth title')" "$_selected" \
    'multi-select returns only chosen rows, not the range between them'
_test_selected_ids=1
printf '%s\n' "$_selection_rows" | nth 'Explicit flags: ' '-m' '--sentinel-menu-flag' 'sentinel-menu' >/dev/null
assert_eq 'sentinel-menu|Explicit flags: |-m|--sentinel-menu-flag' "$(cat "$_test_dir/menu-args")" \
    'nth passes the menu program and settings from its explicit arguments'

_test_selected_ids='9'
if printf '%s\n' "$_selection_rows" | nth 'Pick: ' '' '' '' >/dev/null; then
    fail 'cancelled menu must not return a selection'
fi

episode_maps=$(printf '42\t6\tEpisode 6\nnumeric-key-7\t7\tEpisode 7')
_test_selected_ids=2
assert_eq '7' "$(select_episode_numbers "$episode_maps" "$menu_multi_flag" "$menu_extra_flags" sentinel-menu)" 'episode selector returns the display number'
assert_eq 'numeric-key-7' "$(episode_key_for_number "$episode_maps" 7)" 'display number maps back to provider episode key'

provider_episodes() {
    [ "$1" = 'aniwatch' ] && [ "$2" = 'show-1' ] || return 1
    printf '42\t6\tEpisode 6\nnumeric-key-7\t7\tEpisode 7\n'
}
source=aniwatch
anime_id=show-1
ep_no=7
resolve_episodes "$source" "$anime_id" "$ep_no" "$menu_multi_flag" "$menu_extra_flags" sentinel-menu
assert_eq '7' "$ep_no" 'requested episode number remains user-facing'
assert_eq 'numeric-key-7' "$(episode_key_for_number "$episode_maps" "$ep_no")" 'resolved episode number retains its provider key mapping'
ep_no=42
resolve_episodes "$source" "$anime_id" "$ep_no" "$menu_multi_flag" "$menu_extra_flags" sentinel-menu
assert_eq '6' "$ep_no" 'legacy episode key is normalized to its display number'
ep_no=
_test_selected_ids=2
resolve_episodes "$source" "$anime_id" "$ep_no" "$menu_multi_flag" "$menu_extra_flags" sentinel-menu
assert_eq '7' "$ep_no" 'episode resolver selects from the explicitly supplied menu settings'
assert_eq 'sentinel-menu|Pick an episode: |-m|' "$(cat "$_test_dir/menu-args")" \
    'episode resolver passes the selected menu program through to nth'

index=1
source=all
anime_list=$(printf 'aniwatch:show-1\tExample Show')
resolve_title "$anime_list" "$index" "$source" "$menu_extra_flags" sentinel-menu
assert_eq 'aniwatch' "$source" 'all-mode result selects its source'
assert_eq 'show-1' "$anime_id" 'all-mode result strips the source prefix from its ID'
assert_eq 'Example Show' "$anime_title" 'selected label becomes the clean title'

index=1
source=all
anime_list=$(printf 'miruro:20\tNaruto')
resolve_title "$anime_list" "$index" "$source" "$menu_extra_flags" sentinel-menu
assert_eq 'miruro' "$source" 'all-mode result routes to Miruro'
assert_eq '20' "$anime_id" 'Miruro AniList ID is preserved after routing'

printf 'Core selection checks passed.\n'
