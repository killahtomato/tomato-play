#!/bin/sh

# Offline checks for the Miruro adapter's API normalization and fallback rows.
set -eu

repo_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$repo_dir/providers/miruro.sh"

command -v jq >/dev/null 2>&1 || {
    printf 'Miruro provider checks skipped (jq is not installed).\n'
    exit 0
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_eq() {
    [ "$1" = "$2" ] || fail "$3 (expected <$1>, got <$2>)"
}

cache_read() { return 1; }
cache_write() { :; }
_cpe_key() { printf 'miruro-test-cache-key'; }

TOMATOPLAY_MIRURO_API=https://miruro-api.test
_test_tmp=$(mktemp -d)
trap 'rm -rf "$_test_tmp"' EXIT HUP INT TERM
tp_curl() {
    case "$1" in
        */search\?*)
            printf '%s\n' "$1" >"$_test_tmp/search-url"
            printf '{"results":[{"id":20,"title":{"english":"Naruto","romaji":"NARUTO"}}]}\n'
            ;;
        */episodes/20)
            cat <<'JSON'
{"providers":{
  "slow":{"episodes":{"sub":[
    {"id":"watch/slow/20/sub/show-1","number":1,"title":"Episode One"}
  ]}},
  "fast":{"episodes":{"sub":[
    {"id":"watch/fast/20/sub/show-1","number":1,"title":"Episode One"},
    {"id":"watch/fast/20/sub/show-2","number":2,"title":"Episode Two"}
  ]}}
}}
JSON
            ;;
        */watch/slow/20/sub/show-1)
            printf '{"streams":[{"type":"embed","url":"https://embed.test/player"}]}\n'
            ;;
        */watch/fast/20/sub/show-1)
            printf '{"streams":[{"type":"hls","quality":"720p","url":"https://cdn.test/episode.m3u8"},{"type":"embed","url":"https://embed.test/player"}]}\n'
            ;;
        *) printf 'unexpected test URL: %s\n' "$1" >&2; return 1 ;;
    esac
}

miruro_search 'Naruto & Sasuke' >"$_test_tmp/search"
assert_eq "$(printf '20\tNaruto')" "$(cat "$_test_tmp/search")" 'search maps AniList ID and preferred title'
case "$(cat "$_test_tmp/search-url")" in
    *'query=Naruto%20%26%20Sasuke'*) ;;
    *) fail "search query is URL encoded ($(cat "$_test_tmp/search-url"))" ;;
esac

_episodes=$(miruro_episodes 20)
assert_eq "$(printf '1\t1\tEpisode One\n2\t2\tEpisode Two')" "$_episodes" \
    'episode list chooses the provider with the broadest coverage'

_streams=$(miruro_m3u8 20 1 sub)
assert_eq '720p >https://cdn.test/episode.m3u8' "$_streams" \
    'stream lookup skips embeds and returns a direct HLS stream from a fallback provider'

printf 'Miruro provider checks passed.\n'
