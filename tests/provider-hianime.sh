#!/bin/sh

# Offline contract checks for the hianime adapter and its dispatch routing.
set -eu

repo_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$repo_dir/providers/dispatch.sh"

# Keep this suite offline and independent of the user's cache.
cache_read() { return 1; }
cache_write() { :; }
_cpe_key() { printf 'test-cache-key'; }

# provider_is_direct_stream compares against each provider's base URL; the
# modules that define them are not sourced here, so provide stand-ins.
aniwatch_base="https://aniwatch.example"
gogoanime_base="https://gogoanime.example"
nineanime_base="https://9anime.example"
anidb_base="https://anidb.example"
animeplanet_base="https://animeplanet.example"
anisearch_base="https://anisearch.example"
hianime_base="https://hianime.example"

hianime_search() { printf 'hi-1\tHiAnime %s\n' "$1"; }
hianime_episodes() { printf '5001\t1\tEpisode 1\n5002\t2\tEpisode 2\n'; }
hianime_m3u8() { printf '1080p >https://cdn.example/%s/%s/index.m3u8\n' "$2" "$3"; }
hianime_audio_modes() { printf 'sub\n'; }
hianime_referrer_for_episode() { printf 'https://embed.example/\n'; }
hianime_sub_for_episode() { printf 'https://cdn.example/sub.vtt\n'; }

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_eq() {
    _assert_expected=$1
    _assert_actual=$2
    _assert_name=$3
    [ "$_assert_actual" = "$_assert_expected" ] || fail "$_assert_name (expected <$_assert_expected>, got <$_assert_actual>)"
}

assert_status() {
    _assert_expected_status=$1
    shift
    _assert_actual_status=0
    "$@" >/dev/null 2>&1 || _assert_actual_status=$?
    [ "$_assert_actual_status" -eq "$_assert_expected_status" ] || fail "status for $* (expected $_assert_expected_status, got $_assert_actual_status)"
}

assert_eq "$(printf 'hi-1\tHiAnime query')" "$(provider_search hianime 'query')" 'hianime search dispatch'
assert_eq "$(printf '5001\t1\tEpisode 1\n5002\t2\tEpisode 2')" "$(provider_episodes hianime hi-1)" 'hianime episode row schema and content id'
assert_eq '1080p >https://cdn.example/5001/sub/index.m3u8' "$(provider_m3u8 hianime hi-1 5001 sub)" 'hianime stream dispatch uses the provider episode key'
assert_eq '1080p >https://cdn.example/5001/sub/index.m3u8' "$(provider_m3u8 hianime hi-1 5001 invalid)" 'hianime invalid mode defaults to sub'
assert_eq "$(printf 'sub')" "$(provider_audio_modes hianime hi-1 1)" 'hianime audio mode dispatch'
assert_eq "$(printf 'https://embed.example/')" "$(hianime_referrer_for_episode 5001)" 'hianime referrer helper'

# A hianime watch/embed page is not a directly playable URL.
if provider_is_direct_stream "https://hianime.example/watch/hi-1?ep=5001"; then
    fail 'hianime watch page should not be treated as a direct stream'
fi
# A real CDN playlist is directly playable.
provider_is_direct_stream "https://cdn.example/5001/sub/index.m3u8" || fail 'hianime CDN playlist should be a direct stream'

assert_status 2 provider_search missing query
assert_status 1 provider_audio_modes missing id 1

printf 'provider-hianime: all checks passed\n'
