# Player adapters and source-specific player handoff.
#
# launch_player consumes the prepared playback state set by play_episode and
# stores a foreground mpv status in mpv_exitcode. Keeping command selection here
# separates player behavior from episode/history orchestration.

miruro_play_streams() {
    _miruro_selected=$(printf '%s\n' "$links" | awk -F'>' -v url="$video_link" '$2 == url { print; exit }')
    [ -n "$_miruro_selected" ] || _miruro_selected="best >$video_link"
    _miruro_candidates=$( { printf '%s\n' "$_miruro_selected"; printf '%s\n' "$links" | awk -F'>' -v first="$video_link" '$2 != first'; } )
    mpv_exitcode=1
    while IFS= read -r _miruro_line; do
        _miruro_url=${_miruro_line#*>}
        [ -n "$_miruro_url" ] || continue
        _miruro_hls_flag=""
        case "$_miruro_url" in *[mM]3[uU]8*) _miruro_hls_flag="--demuxer=lavf --demuxer-lavf-format=hls" ;; esac
        _miruro_media_flag=""
        provider_url_has_media_extension "$_miruro_url" && _miruro_media_flag="--ytdl=no"
        video_link=$_miruro_url
        while IFS= read -r _miruro_try_referrer; do
            _miruro_try_origin=$(printf '%s' "$_miruro_try_referrer" | sed -E 's#^(https?://[^/]+).*#\1#')
            if ! _stream_alive "$_miruro_url" "$_miruro_try_referrer" "$_miruro_try_origin"; then
                continue
            fi
            if printf '%s' "$player_function" | grep -q 'flatpak'; then
                flatpak run io.mpv.Mpv $player_extra_flags $_bili_proxy_flag $_miruro_hls_flag $_wl_flags $_miruro_media_flag \
                    --user-agent="$agent" --referrer="$_miruro_try_referrer" --http-header-fields="Origin: $_miruro_try_origin" \
                    --force-media-title="$_title" "$video_link"
            else
                $player_function $player_extra_flags $_room_flag $_miruro_hls_flag $_peek $_wl_flags $_bili_proxy_flag $_miruro_media_flag \
                    --user-agent="$agent" --referrer="$_miruro_try_referrer" --http-header-fields="Origin: $_miruro_try_origin" \
                    --force-media-title="$_title" "$video_link"
            fi
            mpv_exitcode=$?
            [ "$mpv_exitcode" -eq 0 ] && return 0
            warn "That Miruro stream failed with this site origin — trying another."
        done <<EOF
$(miruro_referrer_candidates)
EOF
        warn "That Miruro stream failed in mpv — trying another."
    done <<EOF
$_miruro_candidates
EOF
    return "$mpv_exitcode"
}

source_browser_fallback() {
    _fallback_browser=$(command -v waterfox 2>/dev/null) || return 1
    [ -n "$_fallback_browser" ] || return 1
    _fallback_url=$video_link
    if [ "$source" = "miruro" ]; then
        _fallback_site="${TOMATOPLAY_MIRURO_SITE:-https://www.miruro.to}"
        _fallback_url=$(miruro_watch_url "$anime_id" "$anime_title" "$ep_no" "$_fallback_site")
    elif [ "$source" = "animegg" ] && [ -n "${_animegg_referrer:-}" ]; then
        _fallback_url=$_animegg_referrer
    elif [ -f "$video_link" ]; then
        _fallback_url="file://$(realpath "$video_link" 2>/dev/null || printf '%s' "$video_link")"
    fi
    case "$_fallback_url" in http://* | https://* | file://*) ;; *) return 1 ;; esac
    _fallback_profile=${TOMATOPLAY_WATERFOX_PROFILE:-${XDG_DATA_HOME:-$HOME/.local/share}/tomato-play/waterfox-profile}
    nohup "$_fallback_browser" --no-remote --profile "$_fallback_profile" --kiosk --new-window "$_fallback_url" >/dev/null 2>&1 &
    info "Opening this source in Waterfox kiosk mode."
    return 0
}

download() {
    command -v "yt-dlp" >/dev/null && yt-dlp "$1" --no-skip-unavailable-fragments --fragment-retries infinite -N 16 -o "$download_dir/$2.mp4" $3 && return 0
    ffmpeg -extension_picky 0 -loglevel error -stats -i "$1" -c copy "$download_dir/$2.mp4" $3
}

# Dispatch prepared playback state to the configured player. The function uses
# shared source/media context, while all source-independent setup remains in
# play_episode.
launch_player() {
    case "$player_function" in
        debug) printf "All links:\n%s\nSelected link:\n%s\n" "$links" "$video_link" ;;
        android_mpv) nohup am start --user 0 -a android.intent.action.VIEW -d "$video_link" -n is.xyz.mpv/.MPVActivity -e "title" "$_title" $player_extra_flags >/dev/null 2>&1 & ;;
        android_vlc) nohup am start --user 0 -a android.intent.action.VIEW -d "$video_link" -n org.videolan.vlc/org.videolan.vlc.gui.video.VideoPlayerActivity -e "title" "$_title" $player_extra_flags >/dev/null 2>&1 & ;;
        *flatpak*mpv*)
            if [ "$source" = "miruro" ]; then
                miruro_play_streams || :
            elif [ "$source" = "animegg" ]; then
                _animegg_origin=${_animegg_referrer%/embed/*}
                _animegg_media_flag=""
                provider_url_has_media_extension "$video_link" && _animegg_media_flag="--ytdl=no"
                flatpak run io.mpv.Mpv $player_extra_flags $_animegg_media_flag \
                    --user-agent="$agent" --referrer="$_animegg_referrer" \
                    --http-header-fields="Origin: $_animegg_origin" \
                    --force-media-title="$_title" "$video_link"
                mpv_exitcode=$?
            else
                flatpak run io.mpv.Mpv $player_extra_flags $_bili_proxy_flag $_hls_flags $_wl_flags --force-media-title="$_title" "$video_link"
                mpv_exitcode=$?
            fi
            ;;
        *mpv*)
            _peek=""
            [ "$preview" = 1 ] && _peek="--length=$preview_len"
            if [ -n "$room_role" ]; then room_bootstrap; else _room_flag=""; fi
            if [ "$source" = "miruro" ]; then
                miruro_play_streams || :
            elif [ "$source" = "animegg" ]; then
                _animegg_origin=${_animegg_referrer%/embed/*}
                _animegg_media_flag=""
                provider_url_has_media_extension "$video_link" && _animegg_media_flag="--ytdl=no"
                $player_function $player_extra_flags $_room_flag $_animegg_media_flag \
                    --user-agent="$agent" --referrer="$_animegg_referrer" \
                    --http-header-fields="Origin: $_animegg_origin" \
                    --force-media-title="$_title" "$video_link"
                mpv_exitcode=$?
            else
                [ "$preview" = 1 ] && info "Peeking for ${preview_len}s — mpv will close itself."
                $player_function $player_extra_flags $_room_flag $_hls_flags $_peek $_wl_flags $_bili_proxy_flag --force-media-title="$_title" "$video_link"
                mpv_exitcode=$?
            fi
            ;;
        *iina*)
            if pgrep -f "IINA" >/dev/null 2>&1; then
                nohup $player_function $player_extra_flags --no-stdin --mpv-force-media-title="$_title" "$video_link" >/dev/null 2>&1 &
            else
                nohup $player_function $player_extra_flags --no-stdin --keep-running --mpv-force-media-title="$_title" "$video_link" >/dev/null 2>&1 &
            fi
            ;;
        *vlc*) nohup $player_function $player_extra_flags --play-and-exit --meta-title="$_title" "$video_link" >/dev/null 2>&1 & ;;
        download) "$player_function" "$video_link" "$_title" $player_extra_flags ;;
        *) nohup $player_function $player_extra_flags "$video_link" >/dev/null 2>&1 & ;;
    esac
}
