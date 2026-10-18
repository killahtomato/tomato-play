# Provider adapter: anime-planet.com.
# ============================================================================
# Provider: anime-planet.com
# ============================================================================

animeplanet_base="https://www.anime-planet.com"

animeplanet_search() {
    _page="$(tp_curl "${animeplanet_base}/anime/all?name=$(printf "%s" "$1" | sed 's| |+|g')")" || return 1
    [ -z "$_page" ] && { printf '%s\n' "Connection error: no response from anime-planet.com" >&2; return 1; }
    printf "%s" "$_page" | awk '
        /href="\/anime\/[a-z0-9-]+"/ {
            line=$0; sub(/^.*href="\/anime\//, "", line); sub(/".*/, "", line); slug=line
        }
        /<img[^>]*alt="/ && slug!="" {
            line=$0; sub(/^.*alt="/, "", line); sub(/".*/, "", line); print slug "\t" line; slug=""
        }
    ' | head -n 20
}

animeplanet_episodes() {
    _page="$(tp_curl "${animeplanet_base}/anime/$1")" || return 1
    [ -z "$_page" ] && { printf '%s\n' "Connection error: no response from anime-planet.com" >&2; return 1; }
    printf "%s" "$_page" | sed -nE 's|.*href="[^"]*episode-([0-9]+)".*|\1\t\1\tEpisode \1|p' | sort -n
}

animeplanet_m3u8() {
    # anime-planet provides legal streaming links, not direct video
    _page="$(tp_curl "${animeplanet_base}/anime/$1")" || return 1
    [ -z "$_page" ] && return 1
    printf "Legal streaming available at: https://www.anime-planet.com/anime/%s\n" "$1" >&2
    return 1
}
