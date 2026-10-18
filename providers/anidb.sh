# Provider adapter: anidb.app.
# ============================================================================
# Provider: anidb.app
# ============================================================================

anidb_base="https://anidb.app"

anidb_search() {
    _page="$(tp_curl "${anidb_base}/browse?q=$(printf "%s" "$1" | sed 's| |+|g')")" || return 1
    _page="$(printf "%s" "$_page" | tr '\n' ' ' | sed 's|<a href|\n<a href|g')"
    [ -z "$_page" ] && { printf '%s\n' "Connection error: no response from anidb.app" >&2; return 1; }
    if printf "%s" "$_page" | grep -qi "Just a moment"; then
        if [ "$curl_exe" = "curl" ]; then
            printf '%s\n' "Blocked by cloudflare. Try installing curl-impersonate" >&2
        else
            printf '%s\n' "Blocked by cloudflare." >&2
        fi
        return 1
    fi
    printf "%s" "$_page" | sed -nE 's|.*anime/([a-z0-9-]+-[0-9]+)".*alt="([^"]+)".*|\1\t\2|p' | sed -e "s|&#039;|'|g" -e 's|&quot;|"|g' -e "s|&amp;|\&|g"
}

anidb_desc() {
    _page="$(tp_curl "${anidb_base}/anime/$1" | tr '\n' ' ' | sed 's|<a href|\n<a href|g')"
    mal_id="$(printf "%s" "$_page" | sed -nE 's|.*https://myanimelist.net/anime/([0-9]+)/.*|\1|p')"
    seasons="$(printf "%s" "$_page" | sed -n '/>Seasons</,/>Details</p' | sed -nE 's|.*anime/([^"]+-[0-9]+)"[^>]*title="([^"]+)".*|\1\t\2|p' | sed -e "s|&#039;|'|g")"
    [ -n "$seasons" ] && seasons_option="\nchange_season"
}

anidb_episodes() {
    _page="$(tp_curl "${anidb_base}/api/frontend/anime/${1##*-}/episodes")" || return 1
    [ -z "$_page" ] && { printf '%s\n' "Connection error: no response from anidb.app" >&2; return 1; }
    printf "%s" "$_page" | sed 's|},{|}\n{|g' | sed -nE 's|.*"id":([0-9]+).*"number":([0-9]+).*|\1\t\2\tEpisode \2|p'
}

anidb_m3u8() {
    # The public provider API passes the provider's episode ID explicitly.
    _ep_id="$2"
    _lang="jpn"
    [ "$2" = "dub" ] && _lang="eng"
    _page="$(tp_curl "${anidb_base}/api/frontend/episode/${_ep_id}/languages")"
    _embed="$(printf "%s" "$_page" | sed 's|},{|}\n{|g' | sed -nE 's|.*'"${_lang}"'.*embed_url":"([^"]+)".*|\1|p' | sed 's|\\/|/|g' | head -n 1)"
    [ -z "$_embed" ] && return 1
    _embed_page="$(tp_curl "$_embed")"
    _m3u8_master="$(printf "%s" "$_embed_page" | sed -nE "s|.*file: '([^']*)'.*|\1|p" | head -n 1)"
    tp_curl "${_m3u8_master}" | sed 's|^#EXT-X-STREAM.*x||g; s|,.*|p|g; /^#/d; $!N; s|\n| >|;/EXT-X-I-FRAME/d'
}
