# Episode lifecycle and playback orchestration.

play_episode() {
    [ "$log_episode" = 1 ] && [ "$player_function" != "debug" ] && [ "$player_function" != "download" ] && command -v logger >/dev/null && logger -t tomatoplay "${anime_title} ${ep_no}"
    [ -z "$video_link" ] && get_video_link
    mpv_exitcode=0
    if ! bilibili_playback_preflight; then
        if provider_browser_fallback_allowed "$source" && source_browser_fallback; then
            mpv_exitcode=0
            _browser_fallback_started=1
        else
            return 1
        fi
    else
        _browser_fallback_started=0
    fi
    wait
    [ "$preview" = 1 ] && info "Quick peek — first ${preview_len}s of episode $ep_no."
    _hls_flags=""
    case "$video_link" in
        *[mM]3[uU]8*) _hls_flags="--demuxer=lavf --demuxer-lavf-format=hls" ;;
    esac

    # Remember the audio track used for this show, so "continue" can reuse it
    # without asking again.
    mkdir -p "$resume_dir" 2>/dev/null
    _mode_key=$(printf "mode_%s" "$anime_id" | tr -c '[:alnum:]' '_')
    printf "%s\n" "$mode" >"$resume_dir/$_mode_key" 2>/dev/null

    # Per-episode resume: mpv saves its position to a watch-later file when the
    # user quits; next time the episode plays we rewind resume_back (default
    # 10s) and pick up there. Skip previews, non-mpv players, and android.
    _wl_flags=""
    if [ "$_browser_fallback_started" != 1 ]; then
    case "$player_function" in
        android_mpv | android_vlc | debug | download | *iina* | *vlc*) ;;
        *mpv*)
            _wl_key=$(printf "%s-%s" "$anime_id" "$ep_no" | tr -c '[:alnum:]' '_')
            _wl_dir="$resume_dir/$_wl_key"
            mkdir -p "$_wl_dir" 2>/dev/null
            for _wl in "$_wl_dir"/*; do
                [ -f "$_wl" ] || continue
                _saved=$(grep -m1 -Eo '^(start|pts)=[0-9.]+' "$_wl" 2>/dev/null | cut -d= -f2)
                [ -z "$_saved" ] && _saved=$(grep -m1 -Eo '"(start|pts)": ?[0-9.]+' "$_wl" 2>/dev/null | grep -Eo '[0-9.]+$')
                [ -n "$_saved" ] && break
            done
            _wl_flags="--save-position-on-quit=yes --resume-playback=no --watch-later-directory=$_wl_dir"
            if [ -n "$_saved" ] && [ "$preview" != 1 ]; then
                _resume_pos=$(awk -v val="$_saved" -v back="${resume_back:-10}" 'BEGIN{x=val-back; if (x<0) x=0; printf "%.0f", x}')
                if printf "%s" "$_resume_pos" | grep -qE '^[1-9][0-9]*$'; then
                    _wl_flags="$_wl_flags --start=$_resume_pos"
                    info "Resuming where you left off — rewinding ${resume_back}s."
                fi
            fi
            ;;
    esac

    # Local files aren't episodes, so use the plain name as the player title.
    _title="${anime_title} Episode ${ep_no}"
    [ "$source" = "files" ] && _title="$anime_title"

    _bili_proxy_flag=""
    case "$source:$player_function" in
        bilibili:*mpv*)
            [ -n "${TOMATOPLAY_PROXY:-}" ] && _bili_proxy_flag="--ytdl-raw-options=proxy=${TOMATOPLAY_PROXY}"
            ;;
    esac

    # Opt-in AniList scrobbling, fired in the background so playback never
    # waits (torrents/local/youtube skip — unreliable title matching).
    case "$source" in
        files | nyaa | tpb | youtube) ;;
        *) ( anilist_scrobble "$anime_title" "$ep_no" & ) ;;
    esac

    case "$video_link" in
        magnet:*) torrent_playback; return $? ;;
    esac

    launch_player
    fi
    case "$player_function" in
        *mpv*)
            if [ "$mpv_exitcode" -ne 0 ] && provider_browser_fallback_allowed "$source"; then
                if source_browser_fallback; then
                    mpv_exitcode=0
                else
                    warn "mpv could not play this source (exit status $mpv_exitcode), and Waterfox fallback is unavailable."
                    return 1
                fi
            fi
            [ "$exit_after_play" = 1 ] && [ -z "$_range" ] && exit "$mpv_exitcode"
            ;;
    esac
    replay="$video_link"
    unset video_link
    [ "$source" != "files" ] && update_history "$histfile" "$source" "$anime_id" "$ep_no" "$anime_title"
    [ "$menu_program" != "fzf" ] && wait
}

play() {
    _start=$(printf "%s" "$ep_no" | grep -Eo '^(-1|[0-9]+(\.[0-9]+)?)')
    _end=$(printf "%s" "$ep_no" | grep -Eo '(-1|[0-9]+(\.[0-9]+)?)$')
    [ "$_start" = "-1" ] && ep_no=$(printf "%s" "$ep_list" | tail -n 1) && unset _start
    [ -z "$_end" ] || [ "$_end" = "$_start" ] && unset _start _end
    [ "$_start" = "0" ] && _start=$(printf "%s" "$ep_list" | head -n 1)
    [ "$_end" = "-1" ] && _end=$(printf "%s" "$ep_list" | tail -n 1)
    _line_count=$(printf "%s\n" "$ep_no" | wc -l | tr -d "[:space:]")
    # Marathon mode: -n/--next stretches a single episode into a range that
    # runs to the finale, one episode after another.
    if [ "$auto_next" = 1 ] && [ "$_line_count" = 1 ] && [ -z "$_start" ]; then
        _end=$(printf "%s" "$ep_list" | tail -n 1)
        [ -z "$_end" ] || [ "$_end" = "$ep_no" ] || _start=$ep_no
    fi
    if [ "$_line_count" != 1 ] || [ -n "$_start" ]; then
        [ -z "$_start" ] && _start=$(printf "%s\n" "$ep_no" | head -n 1)
        [ -z "$_end" ] && _end=$(printf "%s\n" "$ep_no" | tail -n 1)
        _range=$(printf "%s\n" "$ep_list" | sed -nE "/^${_start}\$/,/^${_end}\$/p")
        [ -z "$_range" ] && die "Invalid range!"
        for i in $_range; do
            tput clear
            ep_no=$i
            info "Booting up episode $ep_no — enjoy your show!"
            [ "$i" = "$_end" ] && unset _range
            play_episode
        done
    else
        printf "%s" "$ep_list" | grep -q "^$ep_no$" || die "Invalid episode!"
        play_episode
    fi
    [ "$player_function" != "debug" ] && [ "$player_function" != "download" ] && tput cuu1 && tput el
    tput sc
}
