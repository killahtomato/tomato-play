# AnimeGG catalog adapter. Episode playback opens the site's own watch page in
# Waterfox so its embedded player can load the selected subtitle/dub server.

animegg_base="https://www.animegg.org"

animegg_decode_html() {
    sed -e 's/&amp;/\&/g' -e 's/&quot;/"/g' -e "s/&#039;/'/g" \
        -e 's/&#39;/'"'"'/g' -e 's/&lt;/</g' -e 's/&gt;/>/g'
}

animegg_search() {
    _animegg_query=$(_urlencode "$1")
    _animegg_page=$(tp_curl "${animegg_base}/search/?q=${_animegg_query}") || return 1
    printf '%s' "$_animegg_page" | tr '\n' ' ' | sed 's|</a>|</a>\n|g' |
        sed -nE 's|.*<a href="/series/([^"]+)"[^>]*>.*<h2>([^<]+)</h2>.*|\1\t\2|p' |
        animegg_decode_html | awk 'NR <= 20'
}

animegg_episodes() {
    _animegg_page=$(tp_curl "${animegg_base}/series/$1") || return 1
    _animegg_rows=$(printf '%s' "$_animegg_page" | tr '\n' ' ' | sed 's|</li>|</li>\n|g' |
        sed -nE 's|.*<a href="/([^"]+)" class="anm_det_pop"><strong>[^<]* ([0-9]+(\.[0-9]+)?)</strong></a><i class="anititle">([^<]*)</i>.*|\1\t\2\t\4|p' |
        animegg_decode_html | sort -t "$(printf '\t')" -k2,2g -u)
    [ -n "$_animegg_rows" ] || return 1
    printf '%s\n' "$_animegg_rows"
}

animegg_episode_embed_id() {
    _animegg_version=subbed
    [ "$2" = dub ] && _animegg_version=dubbed
    _animegg_page=$(tp_curl "${animegg_base}/$1") || return 1
    printf '%s' "$_animegg_page" | tr '\n' ' ' |
        sed -nE "s/.*data-id=['\"]([0-9]+)['\"][^>]*data-version=\"${_animegg_version}\".*/\\1/p" | head -n 1
}

animegg_referrer_for_episode() {
    _animegg_embed_id=$(animegg_episode_embed_id "$1" "$2") || return 1
    [ -n "$_animegg_embed_id" ] || return 1
    printf '%s/embed/%s' "$animegg_base" "$_animegg_embed_id"
}

animegg_m3u8() {
    _animegg_referrer=$(animegg_referrer_for_episode "$2" "$3") || {
        printf 'best >%s/%s#%sbed\n' "$animegg_base" "$2" "$([ "$3" = dub ] && printf dub || printf sub)"
        return 0
    }
    _animegg_embed_id=${_animegg_referrer##*/}
    _animegg_embed_page=$(tp_curl "$_animegg_referrer") || {
        printf 'best >%s/%s#%sbed\n' "$animegg_base" "$2" "$([ "$3" = dub ] && printf dub || printf sub)"
        return 0
    }
    _animegg_streams=$(printf '%s' "$_animegg_embed_page" | tr '\n' ' ' | sed 's|},|},\n|g' |
        sed -nE 's|.*file: "([^"]+)"[^}]*label: "([^"]+)".*|\2 >\1|p')
    [ -n "$_animegg_streams" ] || {
        printf 'best >%s/%s#%sbed\n' "$animegg_base" "$2" "$([ "$3" = dub ] && printf dub || printf sub)"
        return 0
    }
    printf '%s\n' "$_animegg_streams" | while IFS='>' read -r _animegg_quality _animegg_url; do
        _animegg_quality=$(printf '%s' "$_animegg_quality" | sed 's/[[:space:]]*$//')
        _animegg_url=$(printf '%s' "$_animegg_url" | sed 's/^ *//')
        case "$_animegg_url" in
            http://* | https://*) ;;
            /*) _animegg_url="${animegg_base}${_animegg_url}" ;;
            *) continue ;;
        esac
        printf '%s >%s\n' "$_animegg_quality" "$_animegg_url"
    done
}
