# Provider adapter: gogoanime.by.
# ============================================================================
# Provider: gogoanime.by
# ============================================================================

gogoanime_base="https://gogoanime.by"

gogoanime_search() {
    _page="$(tp_curl "${gogoanime_base}/?s=$(printf "%s" "$1" | sed 's| |+|g')")" || return 1
    [ -z "$_page" ] && { printf '%s\n' "Connection error: no response from gogoanime.by" >&2; return 1; }
    printf "%s" "$_page" | sed -nE 's|.*href="https://gogoanime.by/series/([^"]+)/"[^>]*title="([^"]+)".*|\1\t\2|p' | sed -e "s|&#8211;|-|g" -e "s|&#039;|'|g" | head -n 20
}

gogoanime_episodes() {
    _page="$(tp_curl "${gogoanime_base}/series/$1")" || return 1
    [ -z "$_page" ] && { printf '%s\n' "Connection error: no response from gogoanime.by" >&2; return 1; }
    printf "%s" "$_page" | grep -oE 'episode-[0-9]+' | sed 's|episode-||' | awk '{ print $0 "\t" $0 "\tEpisode " $0 }' | sort -g -u
}

gogoanime_m3u8() {
    # Derive the actual episode URL from the series page (episode slug may differ from series slug)
    _series="$(tp_curl "${gogoanime_base}/series/$1")"
    _ep_href="$(printf "%s" "$_series" | grep -oE 'href="[^"]*episode-'"$2"'-english-subbed/"' | head -n 1 | sed 's|href="||; s|"$||')"
    _ep_url="${_ep_href:-${gogoanime_base}/${1}-episode-${2}-english-subbed}"
    _page="$(tp_curl "$_ep_url")" || return 1
    [ -z "$_page" ] && return 1
    _embed="$(printf "%s" "$_page" | sed -nE 's|.*data-src="([^"]+)".*|\1|p' | head -n 1 | sed 's|&amp;|\&|g')"
    [ -z "$_embed" ] && { printf "best >%s\n" "$_ep_url"; return 0; }
    _embed="$(printf "%s" "$_embed" | sed "s|^\([^ht]\)|${gogoanime_base}/\1|; s|//player|/player|")"
    _embed_page="$(tp_curl "$_embed")"
    _links="$(printf "%s" "$_embed_page" | sed -nE "s|.*file: '([^']*)'.*label: '([^']*)'.*|\2 >\1|p" | sort -g -r)"
    if [ -n "$_links" ]; then
        printf "%s\n" "$_links"
    else
        printf "best >%s\n" "$_embed"
    fi
}
