# Provider adapter: 9anime.tech.
# ============================================================================
# Provider: 9anime.tech
# ============================================================================

nineanime_base="https://9anime.tech"

nineanime_search() {
    _page="$(tp_curl "${nineanime_base}/search?keyword=$(printf "%s" "$1" | sed 's| |+|g')")" || return 1
    [ -z "$_page" ] && { printf '%s\n' "Connection error: no response from 9anime.tech" >&2; return 1; }
    printf "%s" "$_page" | sed -nE 's|.*class="name d-title" href="/watch/([^"]+)"[^>]*>([^<]+)</a>.*|\1\t\2|p' | sed -e "s|&#039;|'|g" -e 's|&quot;|"|g' -e "s|&amp;|\&|g" | head -n 20
}

nineanime_episodes() {
    _page="$(tp_curl "${nineanime_base}/watch/$1")" || return 1
    [ -z "$_page" ] && { printf '%s\n' "Connection error: no response from 9anime.tech" >&2; return 1; }
    printf "%s" "$_page" | grep -oE 'data-num="[0-9]+"' | sed 's|data-num="||; s|"||' | awk '{ print $0 "\t" $0 "\tEpisode " $0 }' | sort -g -u
}

nineanime_m3u8() {
    _page="$(tp_curl "${nineanime_base}/watch/$1")" || return 1
    [ -z "$_page" ] && return 1
    _ep_href="$(printf "%s" "$_page" | grep -oE 'href="/watch/'"$1"'/ep-'"$2"'"' | head -n 1 | sed 's|href="||; s|"$||')"
    _ep_url="${nineanime_base}${_ep_href:-/watch/$1/ep-$2}"
    _page="$(tp_curl "$_ep_url")" || return 1
    [ -z "$_page" ] && return 1
    _ep_data="$(printf "%s" "$_page" | grep -oE 'data-id="[0-9]+"' | head -n 1 | sed 's|data-id="||; s|"||')"
    if [ -z "$_ep_data" ]; then
        printf "best >%s\n" "$_ep_url"
        return 0
    fi
    _embed_page="$(tp_curl "${nineanime_base}/ajax/v2/episode/sources?id=${_ep_data}")"
    _video_url="$(printf "%s" "$_embed_page" | sed -nE 's|.*"source_url":"([^"]+)".*|\1|p' | head -n 1)"
    if [ -z "$_video_url" ]; then
        printf "best >%s\n" "$_ep_url"
        return 0
    fi
    _video_page="$(tp_curl "$_video_url")"
    printf "%s" "$_video_page" | sed -nE "s|.*file: '([^']*)'.*label: '([^']*)'.*|\2 >\1|p" | sort -g -r
}
