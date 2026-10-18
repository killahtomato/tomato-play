#!/bin/sh

# Offline checks for AnimeGG's HTML catalog adapter.
set -eu

repo_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$repo_dir/providers/animegg.sh"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
assert_eq() { [ "$1" = "$2" ] || fail "$3 (expected <$1>, got <$2>)"; }

_urlencode() { printf '%s' "$1" | sed 's| |%20|g'; }
tp_curl() {
    case "$1" in
        */search/*)
            case "$1" in *'q=Naruto%20Shippuden'*) ;; *) fail "search query is encoded: $1" ;; esac
            cat <<'HTML'
<a href="/series/naruto-shippuden" class="mse"><h2>Naruto Shippuden</h2></a>
HTML
            ;;
        */series/naruto-shippuden)
            cat <<'HTML'
<li><div><a href="/naruto-shippuden-episode-2" class="anm_det_pop"><strong>Naruto Shippuden 2</strong></a><i class="anititle">The Akatsuki Makes Its Move</i><a href="/naruto-shippuden-episode-2#subbed"><span>SUBBED</span></a></div></li>
<li><div><a href="/naruto-shippuden-episode-1" class="anm_det_pop"><strong>Naruto Shippuden 1</strong></a><i class="anititle">Homecoming</i><a href="/naruto-shippuden-episode-1#subbed"><span>SUBBED</span></a></div></li>
HTML
            ;;
        */naruto-shippuden-episode-1)
            printf '%s\n' '<a data-id="25881" data-version="subbed">SUBBED</a><a data-id="25882" data-version="dubbed">DUBBED</a>'
            ;;
        */embed/25881)
            printf '%s\n' 'var videoSources = [{file: "/play/248322/video.mp4?for=101790483837468", label: "480p", bk: "", isBk: false }];'
            ;;
        *) fail "unexpected request URL: $1" ;;
    esac
}

_search=$(animegg_search 'Naruto Shippuden')
assert_eq "$(printf 'naruto-shippuden\tNaruto Shippuden')" "$_search" 'search returns the series slug and title'

_episodes=$(animegg_episodes naruto-shippuden)
assert_eq "$(printf 'naruto-shippuden-episode-1\t1\tHomecoming\nnaruto-shippuden-episode-2\t2\tThe Akatsuki Makes Its Move')" \
    "$_episodes" 'episodes are returned in numeric order with their titles'

_referrer=$(animegg_referrer_for_episode naruto-shippuden-episode-1 sub)
assert_eq 'https://www.animegg.org/embed/25881' "$_referrer" 'subbed page resolves to its embed referrer'

_stream=$(animegg_m3u8 naruto-shippuden naruto-shippuden-episode-1 sub)
assert_eq '480p >https://www.animegg.org/play/248322/video.mp4?for=101790483837468' "$_stream" \
    'stream extraction resolves the embed page media URL'

printf 'AnimeGG provider checks passed.\n'
