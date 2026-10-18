# Provider adapter: bilibili (bilibili.com + bilibili.tv, best-effort).
# ============================================================================
# Provider: bilibili (bilibili.com + bilibili.tv, best-effort)
#
# Bilibili is the odd one out among providers: it streams *legally*, but it's
# wrapped in anti-bot (WBI request signing) and, in most regions, geo-locked.
# Metadata (search + season/episode lists) works anywhere; playback only in
# regions where bilibili lets you watch, or through a VPN/proxy. We resolve
# streams to the episode *page* — mpv/iina and `-d` drive it through yt-dlp,
# which muxes the separate audio/video DASH tracks and handles headers.
# ============================================================================

bilibili_base="https://www.bilibili.com"

# Browser fingerprint cookies (buvid3/buvid4): most API endpoints demand them.
_bili_cookies=""
_bili_wbi_key=""
_bili_blocked=0

_bili_get() {
    curl -sL -A "$agent" --max-time 15 $_px_flag -b "$_bili_cookies" \
        -H "Referer: ${bilibili_base}/" "$@"
}

_bili_boot() {
    [ -z "$_bili_cookies" ] || return 0
    _resp="$(_bili_get "https://api.bilibili.com/x/frontend/finger/spi" 2>/dev/null)" || return 1
    _b3="$(printf "%s" "$_resp" | sed -nE 's|.*"b_3":"([^"]*)".*|\1|p')"
    _b4="$(printf "%s" "$_resp" | sed -nE 's|.*"b_4":"([^"]*)".*|\1|p')"
    _bili_cookies="buvid3=${_b3}; buvid4=${_b4}"
    [ -n "${_b3:-}${_b4:-}" ]
}

# WBI: derive the session's mixin key from the two PNG keys in /nav, then sign
# the query params. https://github.com/SocialSisterYi/bilibili-API-collect
_bili_wbi_key() {
    [ -n "$_bili_wbi_key" ] && return 0
    _bili_boot || return 1
    _nav="$(_bili_get "https://api.bilibili.com/x/web-interface/nav" 2>/dev/null)" || return 1
    _lookup="$(printf "%s" "$_nav" | sed -nE 's|.*"img_url":"[^"]*/([^"/]*)\.png".*"sub_url":"[^"]*/([^"/]*)\.png".*|\1\2|p')"
    [ -z "$_lookup" ] && return 1
    _bili_wbi_key="$(printf "%s" "$_lookup" | awk '{
        tab = "46,47,18,2,53,8,23,32,15,50,10,31,58,3,45,35,27,43,5,49,33,9,42,19,29,28,14,39,12,38,41,13,37,48,7,16,24,55,40,61,26,17,0,1,60,51,30,4,22,25,54,21,56,59,6,63,57,62,11,36,20,34,44,52"
        n = split(tab, a, ","); s = ""
        for (i = 1; i <= n; i++) s = s substr($0, a[i] + 1, 1)
        printf "%s", substr(s, 1, 32)
    }')"
    [ -n "$_bili_wbi_key" ]
}

# Sign $1 (a "k=v&k2=v2" param string, values URL-encoded, spaces as +) with
# the WBI key: sort, drop !'()* from values, append wts, md5 over query+key.
_bili_wbi_sign() {
    _ts="$(date +%s)"
    if [ -n "$1" ]; then _q="$1&wts=${_ts}"; else _q="wts=${_ts}"; fi
    _body="$(printf "%s" "$_q" | tr '&' '\n' | sort | tr '\n' '&' | sed 's/&$//; s/[!'\''()*]//g')"
    case "$(uname -s)" in
        Darwin*) _rid="$(printf "%s%s" "$_body" "$_bili_wbi_key" | md5 -q)" ;;
        *) _rid="$(printf "%s%s" "$_body" "$_bili_wbi_key" | md5sum | awk '{ print $1 }')" ;;
    esac
    printf "%s&w_rid=%s" "$_body" "$_rid"
}

# WBI-signed media_bangumi search. Bilibili rate-limits aggressively and can
# soft-return empty results or a v_voucher risk-control challenge; we refresh
# the fingerprint cookies and retry once, then surface a gentle warning.
bilibili_search() {
    _bili_blocked=0
    _attempts=2
    _resp=""
    while [ "$_attempts" -gt 0 ]; do
        _attempts=$((_attempts - 1))
        _bili_wbi_key || { _bili_blocked=1; return 1; }
        _kw="$(printf "%s" "$1" | sed 's|  *|+|g; s| |+|g')"
        _signed="$(_bili_wbi_sign "keyword=${_kw}&page=1&search_type=media_bangumi")"
        _resp="$(curl -sL -A "$agent" --max-time 15 $_px_flag -b "$_bili_cookies" \
            -H "Referer: https://search.bilibili.com/" \
            "https://api.bilibili.com/x/web-interface/wbi/search/type?${_signed}")"
        case "$_resp" in
            *'"code":-412'* | *'"code":-2'*)
                warn "bilibili search is rate-limiting right now — wait a few minutes, or try a VPN/proxy via TOMATOPLAY_PROXY." >&2
                return 1
                ;;
            *v_voucher*)
                # Risk-control challenge on a fresh fingerprint; retire the
                # cookies and try one more time with a brand-new one.
                _bili_cookies=""
                ;;
            *) break ;;
        esac
    done
    [ -z "$_resp" ] && return 1
    case "$_resp" in
        *v_voucher* | *'"result":null'*)
            warn "bilibili search is fighting its anti-bot right now — wait a few minutes or try a VPN/proxy (TOMATOPLAY_PROXY)." >&2
            return 1
            ;;
    esac
    printf "%s" "$_resp" | sed 's|},{"|\n{"|g' \
        | sed -nE 's|.*"title":"(.*)","org_title":.*"season_id":([0-9]+),.*|\2\t\1|p' \
        | sed -e "s|\\\\u003c|<|g" -e "s|\\\\u003e|>|g" -e "s|\\\\u0026|\&|g" -e "s|\\\\u0027|'|g" -e "s|\\\\u0022|\"|g" \
        | sed -e 's|<[^>]*>||g' -e 's|&quot;|"|g' -e "s|&#39;|'|g" -e 's|&amp;|\&|g' \
        | grep -v '^[[:space:]]*$' | head -n 10
}

# Season -> episode list. Metadata is geo-neutral, so this works anywhere.
bilibili_episodes() {
    _bili_boot || return 1
    _resp="$(_bili_get "https://api.bilibili.com/pgc/view/web/season?season_id=$1")"
    case "$_resp" in
        *'"code":0'*) ;;
        *) return 1 ;;
    esac
    # Emit plain episode numbers (1,2,3…, matching -e and ranges). The
    # playurl step maps the number back to bilibili's ep_id by array position.
    _resp="$(printf "%s" "$_resp" | grep -oE '"ep_id":[0-9]+' | cut -d: -f2)"
    _n=0
    while IFS= read -r _ep; do
        _n=$((_n + 1))
        printf "%s\t%s\tEpisode %s\n" "$_n" "$_n" "$_n"
    done <<EOF
$_resp
EOF
}

# Episode -> stream. We return the watch *page* so mpv/iina/(-d yt-dlp) can
# mux the separate video/audio DASH tracks. Region/login locks are reported
# plainly instead of being silently handed to the player.
bilibili_m3u8() {
    _bili_boot || { printf '%s\n' "bilibili fingerprint handshake failed (proxy/VPN problem?) — check TOMATOPLAY_PROXY." >&2; return 1; }
    # $2 is a 1-based episode number; map it to bilibili's ep_id by position.
    _ep_id="$(_bili_get "https://api.bilibili.com/pgc/view/web/season?season_id=$1" | grep -oE '"ep_id":[0-9]+' | cut -d: -f2 | sed -n "${2}p")"
    [ -z "$_ep_id" ] && { printf 'bilibili could not find episode %s.\n' "$2" >&2; return 1; }
    _resp="$(_bili_get "https://api.bilibili.com/pgc/player/web/v2/playurl?ep_id=${_ep_id}&qn=64&fnval=16" \
        -H "Referer: ${bilibili_base}/bangumi/play/ep${_ep_id}")"
    case "$_resp" in
        *'"code":-10403'*)
            printf '%s\n' "bilibili says that episode is geo-restricted for you. Enable a VPN or proxy (TOMATOPLAY_PROXY / HTTPS_PROXY) pointing at an allowed region and try again." >&2
            return 1 ;;
        *'"code":-10400'* | *'"code":-400'* | *'"code":-401'*)
            printf '%s\n' "bilibili wants a login for that one." >&2
            return 1 ;;
        *'"code":-404'*)
            printf '%s\n' "bilibili could not find that episode (it may have been removed)." >&2
            return 1 ;;
        *'"code":0'*) ;;
        *)
            printf 'bilibili refused to hand over a stream for episode %s.\n' "$2" >&2
            return 1 ;;
    esac
    printf "best >%s/bangumi/play/ep%s\n" "$bilibili_base" "$_ep_id"
}
