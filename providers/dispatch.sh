# Public provider API. Adapter implementation details stay in the provider
# modules; callers use only these functions and their documented text formats.

# Adapter names normally follow PROVIDER_OPERATION. Keep the one legacy
# provider slug translation here so each public operation uses the same rule.
_provider_adapter() {
    case "$1" in
        9anime) printf 'nineanime_%s' "$2" ;;
        anidb | aniwatch | gogoanime | animeplanet | anisearch | youtube | \
        bilibili | miruro | animegg | nyaa | tpb | hianime)
            printf '%s_%s' "$1" "$2"
            ;;
        *) return 1 ;;
    esac
}

_unknown_provider() {
    printf 'Unknown provider: %s\n' "$1" >&2
    return 2
}

# provider_search PROVIDER QUERY
#   Output: one content_id<TAB>title row per result. With PROVIDER=all, the
#   content_id is prefixed with provider name (for example, aniwatch:123).
provider_search() {
    _provider="$1"
    _query="$2"
    case "$_provider" in
        all)
            _results=""
            for _source in aniwatch gogoanime 9anime anidb youtube animeplanet anisearch bilibili miruro animegg hianime nyaa tpb; do
                [ "$_source" = "youtube" ] && continue
                _source_results="$(provider_search "$_source" "$_query" 2>/dev/null)"
                if [ -n "$_source_results" ]; then
                    _source_results="$(printf "%s\n" "$_source_results" | sed "s|^|${_source}:|")"
                    if [ -n "$_results" ]; then
                        _results="$(printf "%s\n%s" "$_results" "$_source_results")"
                    else
                        _results="$_source_results"
                    fi
                fi
            done
            [ -n "$_results" ] || return 1
            printf "%s\n" "$_results"
            ;;
        *)
            _adapter="$(_provider_adapter "$_provider" search)" || {
                _unknown_provider "$_provider"
                return 2
            }
            "$_adapter" "$_query"
            ;;
    esac
}

# provider_episodes PROVIDER CONTENT_ID
#   Output: one episode_key<TAB>episode_number<TAB>title row per episode.
provider_episodes() {
    _provider="$1"
    _content_id="$2"
    # Bump the cache namespace when the episode-row schema changes.
    _key="$(_cpe_key "epi-v2" "$_provider" "$_content_id")"
    if cache_read "$_key" 1440; then
        return 0
    fi
    _adapter="$(_provider_adapter "$_provider" episodes)" || {
        _unknown_provider "$_provider"
        return 2
    }
    if ! _episodes_out="$("$_adapter" "$_content_id")"; then
        return 1
    fi
    [ -n "$_episodes_out" ] || return 1
    cache_write "$_key" "$_episodes_out"
    printf "%s\n" "$_episodes_out"
}

# provider_m3u8 PROVIDER CONTENT_ID EPISODE_KEY MODE
#   EPISODE_KEY is the first field returned by provider_episodes. Output:
#   quality > URL rows. Torrent adapters may also emit a
#   torrent > .torrent-URL row to accompany their best > magnet: URL row.
provider_m3u8() {
    _provider="$1"
    _content_id="$2"
    _episode_key="$3"
    _mode="${4:-sub}"
    case "$_mode" in dub) ;; *) _mode=sub ;; esac
    _key="$(_cpe_key "m3u8" "$_provider" "$_content_id" "$_episode_key" "$_mode")"
    if cache_read "$_key" 30; then
        return 0
    fi
    _adapter="$(_provider_adapter "$_provider" m3u8)" || {
        _unknown_provider "$_provider"
        return 2
    }
    if ! _streams_out="$("$_adapter" "$_content_id" "$_episode_key" "$_mode")"; then
        return 1
    fi
    [ -n "$_streams_out" ] || return 1
    cache_write "$_key" "$_streams_out"
    printf "%s\n" "$_streams_out"
}

# provider_audio_modes PROVIDER CONTENT_ID EPISODE_NUMBER
#   Output: zero or more supported mode names, one per line (sub, dub).
provider_audio_modes() {
    case "$1" in
        aniwatch) aniwatch_modes "$2" "$3" ;;
        hianime) hianime_audio_modes "$2" "$3" ;;
        *) return 1 ;;
    esac
}

# provider_trending PROVIDER
#   Output: content_id<TAB>title rows, or fail if the provider has no feed.
provider_trending() {
    case "$1" in
        aniwatch) aniwatch_trending ;;
        *) return 1 ;;
    esac
}

# provider_peer_count PROVIDER CONTENT_ID
#   Output: a nonnegative peer count when supported.
provider_peer_count() {
    case "$1" in
        nyaa) torrent_peer_count "$2" ;;
        *) return 1 ;;
    esac
}

# provider_is_direct_stream URL
#   Return zero when URL is directly playable, rather than a provider's own
#   watch/embed page. Kept here because the deny-list belongs to source routing.
provider_is_direct_stream() {
    _candidate_url="$1"
    case "$_candidate_url" in
        magnet:*) return 0 ;;
        http*) ;;
        *) return 1 ;;
    esac
    case "$_candidate_url" in
        "${animegg_base:-https://www.animegg.org}"/play/*/video.*)
            provider_url_has_media_extension "$_candidate_url" && return 0
            ;;
    esac
    for _provider_base in "$aniwatch_base" "$gogoanime_base" "$nineanime_base" \
        "$anidb_base" "$animeplanet_base" "$anisearch_base" \
        "https://www.miruro.to" "https://api.hiyori.tv" \
        "${animegg_base:-https://www.animegg.org}" "${hianime_base:-https://hianime.at}"; do
        [ -n "$_provider_base" ] || continue
        case "$_candidate_url" in
            "$_provider_base"*) return 1 ;;
        esac
    done
    return 0
}

# Recognize common direct media paths even when the URL has a query string or
# fragment. This is a hint for mpv's URL handling, not a reachability check.
provider_url_has_media_extension() {
    _media_path=${1%%\?*}
    _media_path=${_media_path%%\#*}
    case "${_media_path##*.}" in
        [mM][pP]4 | [mM][kK][vV] | [wW][eE][bB][mM] | [mM][oO][vV] | \
        [mM]4[vV] | [aA][vV][iI] | [tT][sS] | [mM]3[uU]8 | [mM][pP][dD] | \
        [mM][pP][gG] | [mM][pP][eE][gG] | [fF][lL][vV] | [wW][mM][vV] | \
        [oO][gG][vV] | [3][gG][pP]) return 0 ;;
        *) return 1 ;;
    esac
}
