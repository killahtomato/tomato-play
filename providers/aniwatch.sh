# Provider adapter: aniwatch.cx.
# ============================================================================
# Provider: aniwatch.cx
# ============================================================================

aniwatch_base="https://aniwatch.cx"

aniwatch_search() {
    _page="$(tp_curl "${aniwatch_base}/search?q=$(printf "%s" "$1" | sed 's| |+|g')")" || return 1
    [ -z "$_page" ] && { printf '%s\n' "Connection error: no response from aniwatch.cx" >&2; return 1; }
    printf "%s" "$_page" | grep -oE 'anime/[a-z0-9-]+' | sed 's|anime/||' | sort -u | while read -r _id; do
        _title="$(printf "%s" "$_id" | sed 's|^[^-]*-||;s|-| |g')"
        printf "%s\t%s\n" "$_id" "$_title"
    done | head -n 20
}

aniwatch_trending() {
    if cache_read trend 60; then return 0; fi
    _page="$(tp_curl "${aniwatch_base}/")" || return 1
    [ -z "$_page" ] && { printf '%s\n' "Connection error: no response from aniwatch.cx" >&2; return 1; }
    _out="$(printf "%s" "$_page" | grep -oE 'anime/[a-z0-9-]+' | sed 's|anime/||' | sort -u | head -n 20 | while read -r _id; do
        printf "%s\t%s\n" "$_id" "$(printf "%s" "$_id" | sed 's|^[^-]*-||;s|-| |g')"
    done)"
    [ -z "$_out" ] && return 1
    cache_write trend "$_out"
    printf "%s\n" "$_out"
}

aniwatch_episodes() {
    # The anime page only exposes episode 1, but that page's sidebar lists the
    # complete series (number + title per episode).
    _page="$(tp_curl "${aniwatch_base}/anime/$1")" || return 1
    [ -z "$_page" ] && { printf '%s\n' "Connection error: no response from aniwatch.cx" >&2; return 1; }
    _hash="${1%%-*}"
    _ep1="$(printf "%s" "$_page" | grep -oE '/episode/[a-z0-9-]+' | sed -n '/-'"$_hash"'$/p' | grep -- '-1-' | head -n 1)"
    if [ -n "$_ep1" ]; then
        _epage="$(tp_curl "${aniwatch_base}${_ep1}")" || return 1
        if [ -n "$_epage" ]; then
            printf "%s" "$_epage" | awk '
                BEGIN { RS="<a"; FS="\n" }
                /ws-ep/ {
                    ep=""; title=""
                    for (i = 1; i <= NF; i++) {
                        if ($i ~ /data-episode="[0-9]+"/) { ep = $i; sub(/^.*data-episode="/, "", ep); sub(/".*/, "", ep) }
                        if ($i ~ /aria-label="Episode [0-9]+: /) { title = $i; sub(/^.*aria-label="Episode [0-9]+: /, "", title); sub(/".*/, "", title) }
                    }
                    if (ep != "") print ep "\t" ep "\t" (title == "" ? "Episode " ep : title)
                }
            ' | sort -g -t "$(printf '\t')" -k1,1 -u
            return 0
        fi
    fi
    printf "%s" "$_page" | grep -oE '/episode/[a-z0-9-]+' | sed -n '/-'"$_hash"'$/p' | sed -nE 's|^/episode/.*-([0-9]+)-[a-z0-9-]+$|\1\t\1\tEpisode \1|p' | sort -g -u
}

vidnest_stream() {
    # Resolve a VidNest embed (vidnest.fun, used by aniwatch.cx) to a direct
    # HLS URL. $1 = AniList id, $2 = episode number, $3 = sub|dub.
    # Tries aniwave, megaplay and hianime in that order, mirroring the VidNest
    # player's own server list (aniwave is their default; the megaplay DB has
    # corrupt entries for some ids, so it must come after aniwave).
    : "${agent:?}"
    for _endpoint in \
        "https://new.vidnest.fun/aniwave_hls/$1/$2/$3" \
        "https://new.vidnest.fun/animehub/$1/$2/$3" \
        "https://new.vidnest.fun/hianime/anime/$1/$2/$3/hd-2"; do
        _api="$(curl -sL -A "$agent" --max-time 15 "$_endpoint")" || continue
        [ -z "$_api" ] && continue
        printf "%s" "$_api" | grep -qE '"encrypted"|"sources"' || continue
        _enc="$(printf "%s" "$_api" | sed -nE 's/.*"encrypted":(true|false).*/\1/p' | head -n 1)"
        _cipher="$(printf "%s" "$_api" | sed -nE 's/.*"data":"([^"]*)".*/\1/p' | head -n 1)"
        if [ "$_enc" = "true" ] && [ -n "$_cipher" ]; then
            while [ $(( ${#_cipher} % 4 )) -ne 0 ]; do _cipher="${_cipher}="; done
            _custom="RB0fpH8ZEyVLkv7c2i6MAJ5u3IKFDxlS1NTsnGaqmXYdUrtzjwObCgQP94hoeW+/"
            _std="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
            _json="$(printf "%s" "$_cipher" | tr "$_custom" "$_std" | base64 -d 2>/dev/null)"
        else
            _json="$_api"
        fi
        [ -z "$_json" ] && continue
        _url="$(printf "%s" "$_json" | sed -nE 's/.*"sources":\[\{"url":"([^"]*)".*/\1/p' | head -n 1)"
        [ -z "$_url" ] && continue
        printf "best >%s\n" "$_url"
        return 0
    done
    return 1
}

aniwatch_modes() {
    # Report which audio modes (sub/dub) aniwatch offers for episode $2 of
    # anime $1, caching the episode page so aniwatch_m3u8 can reuse it.
    _hash="${1%%-*}"
    if [ "$_aniwatch_cache_key" != "$1|$2" ]; then
        _anime="$(tp_curl "${aniwatch_base}/anime/$1")" || return 1
        _ep1="$(printf "%s" "$_anime" | grep -oE '/episode/[a-z0-9-]+' | sed -n '/-'"$_hash"'$/p' | grep -- '-1-' | head -n 1)"
        [ -z "$_ep1" ] && return 1
        _epage="$(tp_curl "${aniwatch_base}${_ep1}")" || return 1
        _ep_href="$(printf "%s" "$_epage" | grep -oE '/episode/[a-z0-9-]+' | sed -n '/-'"$2"'-'"$_hash"'$/p' | head -n 1)"
        [ -z "$_ep_href" ] && return 1
        _aniwatch_cache_page="$(tp_curl "${aniwatch_base}${_ep_href}")" || return 1
        _aniwatch_cache_key="$1|$2"
    fi
    printf "%s" "$_aniwatch_cache_page" | grep -oE 'https://vidnest\.fun/anime/[0-9]+/[0-9]+/(sub|dub)' | sed -nE 's@.*/(sub|dub)$@\1@p' | sort -u
}

aniwatch_m3u8() {
    _hash="${1%%-*}"
    # $3 = desired audio mode (sub|dub), defaulting to whatever was selected.
    _wanted="${3:-sub}"
    case "$_wanted" in dub) ;; *) _wanted="sub" ;; esac
    if [ "$_aniwatch_cache_key" = "$1|$2" ] && [ -n "$_aniwatch_cache_page" ]; then
        _page="$_aniwatch_cache_page"
    else
        _anime="$(tp_curl "${aniwatch_base}/anime/$1")" || return 1
        # The anime page only lists episode 1, but episode 1's sidebar has every
        # episode href, so derive the target episode URL from there.
        _ep1="$(printf "%s" "$_anime" | grep -oE '/episode/[a-z0-9-]+' | sed -n '/-'"$_hash"'$/p' | grep -- '-1-' | head -n 1)"
        if [ -z "$_ep1" ]; then
            printf "best >%s\n" "${aniwatch_base}/anime/$1/$2"
            return 0
        fi
        _epage="$(tp_curl "${aniwatch_base}${_ep1}")" || return 1
        _ep_href="$(printf "%s" "$_epage" | grep -oE '/episode/[a-z0-9-]+' | sed -n '/-'"$2"'-'"$_hash"'$/p' | head -n 1)"
        [ -z "$_ep_href" ] && _ep_href="$(printf '%s-%s-%s' "${_ep1%-1-*}" "$2" "$_hash")"
        _page="$(tp_curl "${aniwatch_base}${_ep_href}")" || return 1
        _aniwatch_cache_key="$1|$2"
        _aniwatch_cache_page="$_page"
    fi
    [ -z "$_page" ] && return 1
    _vn_all="$(printf "%s" "$_page" | grep -oE 'https://vidnest\.fun/anime/[0-9]+/[0-9]+/(sub|dub)')"
    if [ -n "$_vn_all" ]; then
        _vn="$(printf "%s" "$_vn_all" | grep -- "/$_wanted$" | head -n 1)"
        if [ -z "$_vn" ]; then
            _other="sub"
            [ "$_wanted" = "sub" ] && _other="dub"
            _vn="$(printf "%s" "$_vn_all" | grep -- "/$_other$" | head -n 1)"
            [ -n "$_vn" ] && warn "Audio '$_wanted' unavailable for episode $2, using '$_other'." >&2
        fi
    else
        _vn=""
    fi
    if [ -n "$_vn" ]; then
        _vn_id="$(printf "%s" "$_vn" | sed -nE 's|https://vidnest\.fun/anime/([0-9]+)/.*|\1|p')"
        _vn_ep="$(printf "%s" "$_vn" | sed -nE 's|https://vidnest\.fun/anime/[0-9]+/([0-9]+)/.*|\1|p')"
        _vn_mode="$(printf "%s" "$_vn" | sed -nE 's@.*/(sub|dub)$@\1@p')"
        _stream="$(vidnest_stream "$_vn_id" "$_vn_ep" "$_vn_mode")"
        if [ -n "$_stream" ]; then
            printf "%s\n" "$_stream"
            return 0
        fi
    fi
    _embed="$(printf "%s" "$_page" | sed -nE 's|.*data-src="([^"]+)".*|\1|p' | head -n 1)"
    [ -z "$_embed" ] && { printf "best >%s\n" "${aniwatch_base}${_ep_href}"; return 0; }
    _embed_page="$(tp_curl "$_embed")"
    _links="$(printf "%s" "$_embed_page" | sed -nE "s|.*file: '([^']*)'.*label: '([^']*)'.*|\2 >\1|p" | sort -g -r)"
    if [ -n "$_links" ]; then
        printf "%s\n" "$_links"
    else
        printf "best >%s\n" "$_embed"
    fi
}
