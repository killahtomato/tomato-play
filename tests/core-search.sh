#!/bin/sh

# Offline checks for query relaxation and fuzzy result ranking.
set -eu

repo_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$repo_dir/core/search.sh"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_eq() {
    [ "$1" = "$2" ] || fail "$3 (expected <$1>, got <$2>)"
}

expected_queries=$(printf 'One Piece season 2\nOne Piece 2\nOne Piece\nOne\nPiece\nPiec')
assert_eq "$expected_queries" "$(search_relax 'One Piece season 2')" 'progressively relaxed queries'

provider_search() {
    case "$1:$2" in
        aniwatch:'Cowboy Bebop')
            printf 'movie\tCowboy Bebop: The Movie\n'
            printf 'season\tCowboy Bebop season 2\n'
            printf 'series\tCowboy Bebop\n'
            ;;
        all:Naruto)
            _fixture_i=1
            while [ "$_fixture_i" -le 12 ]; do
                printf 'aniwatch:id-%s\tNaruto series %s\n' "$_fixture_i" "$_fixture_i"
                _fixture_i=$((_fixture_i + 1))
            done
            printf 'bilibili:6384\t火影忍者\nbilibili:5764\t火影忍者 第二篇\n'
            ;;
        *) return 1 ;;
    esac
}
render_torrent_line() { :; }
provider_peer_count() { printf '0\n'; }

ranked_results=$(fuzzy_search aniwatch 'Cowboy Bebop')
first_id=$(printf '%s\n' "$ranked_results" | cut -f 1 | head -n 1)
assert_eq 'series' "$first_id" 'closest title ranks first'
assert_eq 3 "$(printf '%s\n' "$ranked_results" | wc -l | tr -d ' ')" 'all unique matches are returned'

all_results=$(fuzzy_search all Naruto)
assert_eq 10 "$(printf '%s\n' "$all_results" | grep -c '^aniwatch:')" 'all-mode result limit is per provider'
assert_eq 2 "$(printf '%s\n' "$all_results" | grep -c '^bilibili:')" 'lower-ranked Bilibili results survive the source quota'

printf 'Core search checks passed.\n'
