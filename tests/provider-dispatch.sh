#!/bin/sh

# Offline contract checks for the public provider dispatch functions.
set -eu

repo_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$repo_dir/providers/dispatch.sh"

# Keep this suite offline and independent of the user's cache.
cache_read() { return 1; }
cache_write() { :; }
_cpe_key() { printf 'test-cache-key'; }

aniwatch_search() {
    printf 'aw-1\t%s\n' "$1"
}
nineanime_search() { printf 'nine-1\t%s\n' "$1"; }
anidb_search() {
    _test_search_query=$1
    printf 'db-1\tAniDB result\n'
}
gogoanime_search() { :; }
nineanime_search() { printf 'nine-1\t%s\n' "$1"; }
animeplanet_search() { :; }
anisearch_search() { :; }
bilibili_search() { :; }
miruro_search() { printf '20\tMiruro %s\n' "$1"; }
animegg_search() { printf 'naruto\tAnimeGG %s\n' "$1"; }
hianime_search() { printf 'hi-1\tHiAnime %s\n' "$1"; }
nyaa_search() { printf 'nyaa-1\tTorrent result\t20\t3\n'; }
tpb_search() { :; }

anidb_episodes() {
    printf 'provider-episode-42\t7\t%s\n' "$1"
}
nineanime_episodes() { printf 'ep-9\t9\tEpisode 9\n'; }
anidb_m3u8() {
    printf '%s\t%s\t%s\n' "$1" "$2" "$3"
}
nineanime_m3u8() { printf 'best >https://cdn.example/%s/%s.m3u8\n' "$1" "$2"; }
miruro_episodes() { printf '1\t1\tEpisode 1\n'; }
miruro_m3u8() { printf 'best >https://cdn.example/miruro.m3u8\n'; }
animegg_episodes() { printf 'naruto-episode-1\t1\tEpisode 1\n'; }
animegg_m3u8() { printf 'best >https://www.animegg.org/%s#%sbed\n' "$2" "$3"; }
aniwatch_modes() { printf 'sub\ndub\n'; }
aniwatch_trending() { printf 'trend-1\tTrending title\n'; }
torrent_peer_count() { printf '42\n'; }

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

assert_eq "$(printf 'aw-1\tquery words')" "$(provider_search aniwatch 'query words')" 'provider search output and query argument'
assert_eq "$(printf 'nine-1\tquery')" "$(provider_search 9anime query)" 'legacy 9anime slug maps to its adapter prefix'

_expected_all=$(printf 'aniwatch:aw-1\tquery\n9anime:nine-1\tquery\nanidb:db-1\tAniDB result\nmiruro:20\tMiruro query\nanimegg:naruto\tAnimeGG query\nhianime:hi-1\tHiAnime query\nnyaa:nyaa-1\tTorrent result\t20\t3')
assert_eq "$_expected_all" "$(provider_search all query)" 'all search source prefixes and extra torrent columns'

assert_eq "$(printf 'provider-episode-42\t7\tanime-9')" "$(provider_episodes anidb anime-9)" 'episode row schema and content ID argument'
assert_eq "$(printf 'ep-9\t9\tEpisode 9')" "$(provider_episodes 9anime anime-9)" '9anime episode adapter routing'
assert_eq "$(printf 'anime-9\tprovider-episode-42\tdub')" "$(provider_m3u8 anidb anime-9 provider-episode-42 dub)" 'stream arguments preserve the provider episode key'
assert_eq 'best >https://cdn.example/anime-9/ep-9.m3u8' "$(provider_m3u8 9anime anime-9 ep-9 sub)" '9anime stream adapter routing'
assert_eq "$(printf 'anime-9\tprovider-episode-42\tsub')" "$(provider_m3u8 anidb anime-9 provider-episode-42 invalid-mode)" 'invalid audio mode defaults to sub'
assert_eq "$(printf 'anime-9\tprovider-episode-42\tsub')" "$(provider_m3u8 anidb anime-9 provider-episode-42)" 'missing audio mode defaults to sub'
assert_eq "$(printf '20\tMiruro Naruto')" "$(provider_search miruro Naruto)" 'Miruro search dispatch'
assert_eq "$(printf '1\t1\tEpisode 1')" "$(provider_episodes miruro 20)" 'Miruro episode dispatch'
assert_eq 'best >https://cdn.example/miruro.m3u8' "$(provider_m3u8 miruro 20 1 sub)" 'Miruro stream dispatch'
assert_eq "$(printf 'naruto-episode-1\t1\tEpisode 1')" "$(provider_episodes animegg naruto)" 'AnimeGG episode dispatch'
assert_eq 'best >https://www.animegg.org/naruto-episode-1#dubbed' "$(provider_m3u8 animegg naruto naruto-episode-1 dub)" 'AnimeGG opens the requested dub page'

assert_eq "$(printf 'sub\ndub')" "$(provider_audio_modes aniwatch anime-9 7)" 'audio mode output'
assert_eq "$(printf 'trend-1\tTrending title')" "$(provider_trending aniwatch)" 'trending output'
assert_eq '42' "$(provider_peer_count nyaa torrent-1)" 'peer count output'

aniwatch_base='https://aniwatch.example'
gogoanime_base='https://gogo.example'
nineanime_base=''
anidb_base=''
animeplanet_base=''
anisearch_base=''
assert_status 0 provider_is_direct_stream 'magnet:?xt=urn:btih:abc'
assert_status 0 provider_is_direct_stream 'https://cdn.example/video.m3u8'
assert_status 1 provider_is_direct_stream 'https://aniwatch.example/watch/abc'
assert_status 1 provider_is_direct_stream 'https://gogo.example/episode/abc'
assert_status 1 provider_is_direct_stream 'https://api.hiyori.tv/episodes/20'
assert_status 1 provider_is_direct_stream 'https://www.miruro.to/watch/20'
assert_status 1 provider_is_direct_stream 'https://www.animegg.org/naruto-episode-1'
assert_status 0 provider_is_direct_stream 'https://www.animegg.org/play/248322/video.mp4?for=101790483837468'
assert_status 1 provider_is_direct_stream 'relative/path'
for _media_url in \
    'https://cdn.example/video.mp4' \
    'https://cdn.example/video.mp4?token=abc' \
    'https://cdn.example/video.m3u8#variant' \
    'https://cdn.example/video.mkv' \
    'https://cdn.example/video.webm' \
    'https://cdn.example/video.mov' \
    'https://cdn.example/video.m4v' \
    'https://cdn.example/video.avi' \
    'https://cdn.example/video.ts' \
    'https://cdn.example/manifest.mpd'; do
    assert_status 0 provider_url_has_media_extension "$_media_url"
done
assert_status 1 provider_url_has_media_extension 'https://cdn.example/page?file=video.mp4'
assert_status 1 provider_url_has_media_extension 'https://cdn.example/video.mp4/page'

assert_status 2 provider_search missing query
assert_status 2 provider_episodes missing id
assert_status 2 provider_m3u8 missing id episode sub
assert_status 1 provider_audio_modes unsupported id 1
assert_status 1 provider_trending unsupported
assert_status 1 provider_peer_count unsupported id

printf 'Provider dispatch checks passed.\n'
