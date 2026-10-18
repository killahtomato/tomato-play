# Provider adapter: anisearch.com.
# ============================================================================
# Provider: anisearch.com
# ============================================================================

anisearch_base="https://www.anisearch.com"

anisearch_search() {
    _page="$(tp_curl "${anisearch_base}/anime/index?text=$(printf "%s" "$1" | sed 's| |+|g')")" || return 1
    [ -z "$_page" ] && { printf '%s\n' "Connection error: no response from anisearch.com" >&2; return 1; }
    printf "%s" "$_page" | sed -nE 's|.*href="/anime/([0-9]+)".*<[^>]*>([^<]+)</a>.*|\1\t\2|p' | head -n 20
}

anisearch_episodes() {
    # anisearch is an aggregator, doesn't provide direct episodes
    printf "1\t1\tEpisode 1\n"
}

anisearch_m3u8() {
    # anisearch provides stream availability info
    _page="$(tp_curl "${anisearch_base}/anime/$1")" || return 1
    [ -z "$_page" ] && return 1
    printf "Stream availability info at: https://www.anisearch.com/anime/%s\n" "$1" >&2
    return 1
}
