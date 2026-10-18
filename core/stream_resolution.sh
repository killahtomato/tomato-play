# Playback orchestration and preflight helpers shared by the CLI entry point.

miruro_referrer_candidates() {
    {
        [ -z "${TOMATOPLAY_MIRURO_REFERER:-}" ] || printf '%s\n' "$TOMATOPLAY_MIRURO_REFERER"
        printf '%s\n' 'https://www.miruro.to/' 'https://www.miruro.tv/'
    } | awk 'NF && !seen[$0]++'
}

miruro_watch_url() {
    _mw_base=${4:-${TOMATOPLAY_MIRURO_SITE:-https://www.miruro.to}}
    _mw_slug=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g')
    [ -n "$_mw_slug" ] || _mw_slug="anime-$1"
    printf '%s/watch/%s/%s/%s' "${_mw_base%/}" "$1" "$_mw_slug" "$3"
}

# All HTTP and local media sources can use the browser fallback. Torrent
# playback owns its own webtorrent player lifecycle and stays out of this path.
provider_browser_fallback_allowed() {
    case "$1" in
        nyaa | tpb) return 1 ;;
        *) return 0 ;;
    esac
}

# Bilibili's API can hand us a valid episode page even when yt-dlp cannot
# extract media from this IP. Check extraction before launching a detached
# player, whose stderr is intentionally hidden. This also applies the same
# configured proxy used by curl to yt-dlp.
bilibili_playback_preflight() {
    [ "$source" = "bilibili" ] || return 0
    [ "$player_function" = "debug" ] && return 0
    if ! command -v yt-dlp >/dev/null 2>&1; then
        printf '%s\n' "Bilibili playback needs yt-dlp to resolve its DASH streams." >&2
        return 1
    fi

    if [ -n "${TOMATOPLAY_PROXY:-}" ]; then
        if _yt_error=$(yt-dlp --proxy "$TOMATOPLAY_PROXY" --simulate --no-warnings --no-playlist "$video_link" 2>&1 >/dev/null); then
            return 0
        else
            _yt_status=$?
        fi
    else
        if _yt_error=$(yt-dlp --simulate --no-warnings --no-playlist "$video_link" 2>&1 >/dev/null); then
            return 0
        else
            _yt_status=$?
        fi
    fi
    _bilibili_extraction_error "$_yt_error" "$_yt_status"
}

_bilibili_extraction_error() {
    _yt_error_text="$1"
    _yt_status="$2"
    if printf "%s" "$_yt_error_text" | grep -Eiq 'HTTP Error 412|HTTP 412|Precondition Failed'; then
        printf '%s\n' "bilibili rejected yt-dlp's playback request (HTTP 412: Precondition Failed). This is usually an anti-bot or request-fingerprint check, not proof of a geo-block. Try updating yt-dlp; if it continues, wait and retry or use an allowed-region proxy with TOMATOPLAY_PROXY." >&2
        return 1
    fi
    if printf "%s" "$_yt_error_text" | grep -Eiq 'not available in your country|geo.?restrict|geo.?block|country restriction|region restriction'; then
        printf '%s\n' "bilibili found the episode, but yt-dlp says playback is geo-restricted for this IP. Route playback through an allowed region with TOMATOPLAY_PROXY (or a system VPN), then retry." >&2
        return 1
    fi
    _yt_summary=$(printf "%s\n" "$_yt_error_text" | tail -n 3)
    [ -n "$_yt_summary" ] || _yt_summary="yt-dlp exited with status $_yt_status and gave no diagnostic."
    printf '%s\n' "bilibili episode extraction failed before playback: $_yt_summary" >&2
    return 1
}

# True if a provider_m3u8 result is an actual stream, not a broken page-URL
# fallback (which mpv can't play). Keeps aniwatch's vidnest HLS and any other
# real CDN/player link; drops anything pointing back at a scraper site.
_probe_playable() {
    while IFS= read -r _vline; do
        _vlink="${_vline#*>}"
        case "$_vlink" in
            "") continue ;;
            # Magnets are playable the same way any torrent is — webtorrent.
            magnet:*) return 0 ;;
            http*) ;;
            *) continue ;;
        esac
        case "$_vlink" in
            "${animegg_base:-https://www.animegg.org}"/*) return 0 ;;
        esac
        provider_is_direct_stream "$_vlink" && return 0
    done
    return 1
}

# Shallow reachability check on a resolved stream before handing it to the
# player. Distinguishes "this CDN is having a moment" (HTTP 5xx, timeouts,
# dropped connections) from a genuinely working link, so a dead server no
# longer means a silent 20-second mpv hang. Conservative on 403s — some CDNs
# block curl but still serve the player.
_stream_alive() {
    _stream_probe_range=""
    [ "${source:-}" != "animegg" ] || _stream_probe_range="--range 0-0"
    case "$1" in
        # Magnets have no URL to probe — webtorrent handles discovery at play.
        magnet:*) return 0 ;;
    esac
    if [ -n "${2:-}" ]; then
        _code="$(tp_curl_status $_stream_probe_range -e "$2" \
            -H "Origin: ${3:-$2}" "$1")"
    else
        _code="$(tp_curl_status $_stream_probe_range "$1")"
    fi
    [ $? -ne 0 ] && return 1
    case "$_code" in
        2* | 3*) return 0 ;;
        5* | 404 | 410 | 000) return 1 ;;
        *) return 0 ;;
    esac
}

# Miruro links may enforce the site origin. Probe against both public domains
# and retain whichever Referer succeeds so mpv begins with the same context.
_stream_candidate_alive() {
    if [ "$source" = "animegg" ]; then
        [ -n "${_animegg_referrer:-}" ] || return 1
        _animegg_origin=${_animegg_referrer%/embed/*}
        _stream_alive "$1" "$_animegg_referrer" "$_animegg_origin"
        return $?
    fi
    if [ "$source" != "miruro" ]; then
        _stream_alive "$1"
        return $?
    fi
    while IFS= read -r _ref_candidate; do
        _origin_candidate=$(printf '%s' "$_ref_candidate" | sed -E 's#^(https?://[^/]+).*#\1#')
        if _stream_alive "$1" "$_ref_candidate" "$_origin_candidate"; then
            _miruro_referrer=$_ref_candidate
            _miruro_origin=$_origin_candidate
            return 0
        fi
    done <<EOF
$(miruro_referrer_candidates)
EOF
    return 1
}

# ============================================================================
# Quality Selection
# ============================================================================

select_quality() {
    case "$1" in
        best) _result=$(printf "%s" "$links" | head -n 1) ;;
        worst) _result=$(printf "%s" "$links" | grep -E '^[0-9]{3,4}' | tail -n 1) ;;
        *) _result=$(printf "%s" "$links" | grep -m 1 "$1") ;;
    esac
    [ -z "$_result" ] && warn "$1 not found, defaulting to best" && _result=$(printf "%s" "$links" | head -n 1)
    video_link=$(printf "%s" "$_result" | cut -d ">" -f 2)
}

get_video_link() {
    _episode_key="$(episode_key_for_number "$episode_maps" "$ep_no")"
    [ -n "$_episode_key" ] || die "No provider episode key found for episode $ep_no."
    links=$(provider_m3u8 "$source" "$anime_id" "$_episode_key" "$mode" | sort -g -r -s)
    [ -z "$links" ] && die "No streams available for that one right now :("
    info "We found some streams on $source."
    _animegg_referrer=""
    [ "$source" != "animegg" ] || _animegg_referrer=$(animegg_referrer_for_episode "$_episode_key" "$mode")
    # Prefer the requested quality, otherwise the best one.
    case "$quality" in
        worst) _cand="$(printf "%s\n" "$links" | grep -E '^[0-9]{3,4}' | tail -n 1)" ;;
        *) _cand="$(printf "%s\n" "$links" | grep -m 1 "$quality")" ;;
    esac
    [ -z "$_cand" ] && _cand="$(printf "%s\n" "$links" | head -n 1)"
    video_link="$(printf "%s" "$_cand" | cut -d ">" -f 2)"
    _miruro_referrer=""
    _miruro_origin=""
    if ! _stream_candidate_alive "$video_link"; then
        warn "That stream's host isn't answering — skipping to the next one."
        # Fall through to the next alive server/quality instead of a dead hang.
        video_link="$(printf "%s\n" "$links" | while IFS= read -r _line; do
            [ "$_line" = "$_cand" ] && continue
            _try="$(printf "%s" "$_line" | cut -d ">" -f 2)"
            if _stream_candidate_alive "$_try"; then printf "%s\n" "$_try"; break; fi
        done | head -n 1)"
        [ -z "$video_link" ] && die "Every stream for that one is down right now — try again in a bit :("
        warn "Streams on $source are flaky — if it stutters, rerun in a minute."
    fi
    [ -z "$video_link" ] && die "Couldn't grab a stream link, sorry! :/"
}
