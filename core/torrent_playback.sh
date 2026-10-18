# Torrent metadata, file selection, browser/player handoff, and streaming.

# Serve ONE file of a torrent with webtorrent and play it with our player,
# resuming where we left off for that file (mpv watch-later per stream). Used
# for a single pickup and, in a loop, for the season-pack marathon. Returns the
# player's exit code (0 = finished normally so the marathon can advance).
torrent_stream_one() {
    _si="$1" _sp="$2" _sl="$3" _sn="$4"
    [ -n "$_sp" ] || { warn "No stream URL (torrent metadata missing) — grab the magnet instead: ${video_link:-?}"; return 1; }
    _wtport="${TOMATOPLAY_TORRENT_PORT:-8000}"
    while command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | grep -q ":$_wtport "; do
        _wtport=$((_wtport + 1))
    done
    _ih="$(basename "$_torrent_src" | sed 's|\.torrent$||')"
    _turl="http://127.0.0.1:${_wtport}/webtorrent/${_ih}/$(_urlencode "$_sp")"
    _subflag=""
    if [ -n "${5:-}" ]; then
        _subflag="--sub-file=\"http://127.0.0.1:${_wtport}/webtorrent/${_ih}/$(_urlencode "$5")\""
    fi
    info "Streaming '$_sl'${_sn:+ (episode $_sn)} — buffering via webtorrent, then opening your player…"
    webtorrent "$_torrent_src" -s "$_si" -p "$_wtport" --quiet &
    _wtpid=$!
    _wait_n=0
    _code=000
    while [ "$_wait_n" -lt 30 ]; do
        _wait_n=$((_wait_n + 1))
        _fill=$((_wait_n * 3)); [ "$_fill" -gt 30 ] && _fill=30
        _left=$((30 - _fill))
        _mouth="C"; [ $((_wait_n % 2)) -eq 1 ] && _mouth="o"
        printf '\r  \033[1;33m%s\033[0m%.*s\033[2m%.*s\033[0m' \
            "$_mouth" "$_fill" "$(printf '%*s' "$_fill" '' | tr ' ' '=')" \
            "$_left" "$(printf '%*s' "$_left" '' | tr ' ' '.')"
        _code="$(curl -s -o /dev/null --max-time 2 -w '%{http_code}' "http://127.0.0.1:${_wtport}/webtorrent/" 2>/dev/null)"
        [ "${_code#2}" != "$_code" ] && break
        sleep 1
    done
    printf '\r  \033[2K'
    _trc=1
    if [ "${_code#2}" = "$_code" ]; then
        warn "webtorrent's stream never came up — grab the magnet instead: ${video_link:-?}"
    else
        # Per-file resume (mpv watch-later, keyed on infohash+file index).
        _rwl="$resume_dir/rt_$(printf '%s%s' "$_ih" "$_si" | tr -c '[:alnum:]' '_')"
        mkdir -p "$_rwl" 2>/dev/null
        _rfl="--save-position-on-quit=yes --resume-playback=no --watch-later-directory=$_rwl"
        _saved=""
        for _wl in "$_rwl"/*; do
            [ -f "$_wl" ] || continue
            _saved=$(grep -m1 -Eo '^(start|pts)=[0-9.]+' "$_wl" 2>/dev/null | cut -d= -f2)
            [ -z "$_saved" ] && _saved=$(grep -m1 -Eo '"(start|pts)": ?[0-9.]+' "$_wl" 2>/dev/null | grep -Eo '[0-9.]+$')
            [ -n "$_saved" ] && break
        done
        if [ -n "$_saved" ]; then
            _rpos=$(awk -v val="$_saved" -v back="${resume_back:-10}" 'BEGIN{x=val-back; if(x<0)x=0; printf "%.0f", x}')
            printf "%s" "$_rpos" | grep -qE '^[1-9][0-9]*$' && _rfl="$_rfl --start=$_rpos"
        fi
        case "$player_function" in
            *iina*) open -a IINA "$_turl" ;;
            *vlc*) $player_function --play-and-exit "$_turl" ;;
            *)
                if [ -n "$room_role" ]; then room_bootstrap; else _room_flag=""; fi
                $player_function $_rfl $player_extra_flags $_room_flag $_subflag --force-media-title="$_sl" "$_turl"
                ;;
        esac
        _trc=$?
        [ "$_trc" != "0" ] && warn "player exited ($_trc) — grab the magnet instead: ${video_link:-?}"
    fi
    kill "$_wtpid" 2>/dev/null
    wait "$_wtpid" 2>/dev/null
    return "$_trc"
}

torrent_playback() {
    # Torrents (nyaa): stream straight into the player via webtorrent-cli.
    # Without it, fall back to a clean handoff — print the magnet, copy it to
    # the clipboard, and save the .torrent — instead of failing silently.
    if printf "%s" "$video_link" | grep -q '^magnet:?'; then
        _torrent_file="$(printf "%s\n" "${links:-}" | grep '^torrent >' | head -n 1 | cut -d'>' -f2-)"
        _torrent_peers=0
        _torrent_src="$video_link"
        _torrent_index=""
        _td=""
        if command -v webtorrent >/dev/null 2>&1; then
            case "$player_function" in
                *vlc*) _torrent_viewer="--vlc" ;;
                *iina*) _torrent_viewer="--iina" ;;
                download) _torrent_viewer="download" ;;
                debug) printf "Magnet:\n%s\n" "$video_link"; exit 0 ;;
                *) _torrent_viewer="--mpv" ;;
            esac
            [ -n "$cast_dest" ] && _torrent_viewer="$cast_dest"
            # Preflight: fetch metadata + confirm seeders, and KEEP the .torrent
            # file webtorrent drops — feeding it the file (instead of the magnet)
            # skips the silent metadata/ready network wait entirely.
            _td="$(mktemp -d)" || exit 1
            if cd "$_td" && timeout "${TOMATOPLAY_TORRENT_PEEK:-30}" webtorrent downloadmeta "$video_link" -o . >/dev/null 2>&1; then
                _torrent_peers=1
                _torrent_file2="$(ls "$_td"/*.torrent 2>/dev/null | head -n 1)"
                [ -n "$_torrent_file2" ] && _torrent_src="$_torrent_file2"
            fi
            if [ "$_torrent_peers" = "1" ]; then
                # Multi-file torrent? List its contents and let the user pick
                # which episode to stream (webtorrent info reads .torrent
                # directly, no network/ready wait).
                if [ -n "$_torrent_file2" ]; then
                    _flist="$(webtorrent info "$_torrent_file2" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]][[:space:]]*/ /g' \
                        | grep -oE '"path": "[^"]*", "name": "[^"]*", "length": [0-9]+' \
                        | sed -nE 's|"path": "([^"]*)", "name": "([^"]*)", "length": ([0-9]+)|\1\t\2\t\3|p' \
                        | awk -F'\t' '
                            { idx = NR - 1 }
                            $2 ~ /\.(mkv|mp4|webm|avi|mov|m4v|ts|flv|wmv|mpg|mpeg|3gp)$/ {
                                sz = $3; unit = "B"
                                if (sz >= 1073741824) { sz = sz / 1073741824; unit = "GB" }
                                else if (sz >= 1048576) { sz = sz / 1048576; unit = "MB" }
                                else if (sz >= 1024) { sz = sz / 1024; unit = "KB" }
                                printf "%d\t%s\t%s (%s %.2f %s)\n", idx, $1, $2, $3, sz, unit
                            }')"
                    _fcount="$(printf '%s\n' "${_flist:-}" | grep -vc '^$' 2>/dev/null)"
                    # Bonus: collect any bundled subtitle tracks so we can
                    # auto-attach the matching one to the pick.
                    _sublist="$(webtorrent info "$_torrent_file2" 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]][[:space:]]*/ /g' \
                        | grep -oE '"path": "[^"]*", "name": "[^"]*", "length": [0-9]+' \
                        | sed -nE 's|"path": "([^"]*)", "name": "([^"]*)", "length": [0-9]+|\1\t\2|p' \
                        | awk -F'\t' '$2 ~ /\.(srt|ass|ssa|vtt)$/ { printf "%s\t%s\n", $1, $2 }')"
                    if [ "$_fcount" -gt "1" ]; then
                        info "That torrent bundles several files — pick the one to play:"
                        _fchoice="$(printf '%s\n' "$_flist" | nl -w 2 | sed 's/^[[:space:]]//' | nth "Pick a file: " "" "$menu_extra_flags" "$menu_program")"
                        _torrent_index="$(printf '%s' "$_fchoice" | cut -f 1)"
                        _torrent_path="$(printf '%s' "$_fchoice" | cut -f 2)"
                        _torrent_label="$(printf '%s' "$_torrent_path" | sed 's|.*/||')"
                    elif [ "$_fcount" = "1" ]; then
                        _torrent_index="$(printf '%s' "$_flist" | cut -f 1)"
                        _torrent_path="$(printf '%s' "$_flist" | cut -f 2)"
                        _torrent_label="$(printf '%s' "$_torrent_path" | sed 's|.*/||')"
                    fi
                fi
                _isel=""
                [ -n "$_torrent_index" ] && _isel="-s $_torrent_index"
                if [ "$_torrent_viewer" = "download" ]; then
                    info "Torrenting '$_title' into $download_dir — webtorrent will seed while it grabs it."
                    webtorrent download "$_torrent_src" $_isel -o "$download_dir"
                    _trc=$?
                    [ "$_trc" != "0" ] && warn "webtorrent had trouble (exit $_trc) — grab the magnet instead: $video_link"
                    rm -rf "$_td"
                    exit 0
                fi
                # Casting: webtorrent serves + pushes to the TV itself.
                if [ -n "$cast_dest" ]; then
                    info "Casting '$_torrent_label' to your TV — keep your device awake…"
                    webtorrent "$_torrent_src" $_isel "$_torrent_viewer"
                    _trc=$?
                    [ "$_trc" != "0" ] && warn "cast session ended oddly (exit $_trc) — grab the magnet instead: $video_link"
                    rm -rf "$_td"
                    exit 0
                fi
                # Auto-attach a bundled subtitle track that matches the picked
                # episode (same stem, any of srt/ass/ssa/vtt).
                _torrent_sub=""
                if [ -n "${_sublist:-}" ] && [ -n "$_torrent_path" ]; then
                    _vstem="$(printf '%s' "$_torrent_path" | sed -E 's|.*/||; s|\.[^.]*$||')"
                    _torrent_sub="$(printf '%s\n' "$_sublist" | awk -F'\t' -v v="$_vstem" '
                        { n = $2; sub(/\.[^.]*$/, "", n); sub(/^.*\//, "", n)
                          if (n == v) { print $1; found = 1 } }
                        END { if (!found) print "" }' | head -n 1)"
                fi
                # Serve the picked file(s) with webtorrent (no player flag) and play them
                # with OUR player — webtorrent's own player spawning is
                # unreliable. With -n and a multi-file torrent this becomes a
                # season-pack marathon, advancing file by file with per-episode
                # resume until the pack runs out.
                _torrent_label="$(printf '%s' "${_torrent_label:-$_title}")"
                if [ "$auto_next" = "1" ] && [ "${_fcount:-0}" -gt "1" ] && [ -n "$_flist" ]; then
                    _TAB="$(printf '\t')"
                    _pack_total="$(printf '%s\n' "$_flist" | grep -c .)"
                    _pack_n=0
                    printf '%s\n' "$_flist" | awk -v FS="$_TAB" -v s="${_torrent_index:-0}" '$1 + 0 >= s + 0 { print }' |
                        while IFS= read -r _pack; do
                            _pack_i="$(printf '%s' "$_pack" | cut -f 1)"
                            _pack_p="$(printf '%s' "$_pack" | cut -f 2)"
                            _pack_l="$(printf '%s' "$_pack_p" | sed 's|.*/||')"
                            _pack_sub=""
                            if [ -n "${_sublist:-}" ]; then
                                _psv="$(printf '%s' "$_pack_p" | sed -E 's|.*/||; s|\.[^.]*$||')"
                                _pack_sub="$(printf '%s\n' "$_sublist" | awk -F'\t' -v v="$_psv" '
                                    { n = $2; sub(/\.[^.]*$/, "", n); sub(/^.*\//, "", n)
                                      if (n == v) { print $1; found = 1 } }
                                    END { if (!found) print "" }' | head -n 1)"
                            fi
                            _pack_n=$((_pack_n + 1))
                            torrent_stream_one "$_pack_i" "$_pack_p" "$_pack_l" "$_pack_n/$_pack_total" "$_pack_sub" || break
                        done
                else
                    torrent_stream_one "${_torrent_index:-0}" "${_torrent_path:-}" "${_torrent_label}" "" "${_torrent_sub:-}" || true
                fi
                rm -rf "$_td"
                exit 0
            else
                warn "No reachable seeders for that torrent (its peers are gone) — handing you the magnet instead."
            fi
            [ -n "$_td" ] && cd / && rm -rf "$_td"
        fi
        if [ "$_torrent_peers" != "1" ]; then
            [ -n "$_torrent_file" ] && {
                _nt_name="$(printf "%s" "$_title" | tr -c 'A-Za-z0-9._-' '_').torrent"
                curl -sL -m 30 -A "$agent" "$_torrent_file" -o "$download_dir/$_nt_name" 2>/dev/null \
                    && info "Saved $download_dir/$_nt_name"
            }
            printf "    magnet: %s\n" "$video_link"
            if command -v xclip >/dev/null 2>&1; then printf "%s" "$video_link" | xclip -selection clipboard; info "Magnet copied to clipboard."
            elif command -v wl-copy >/dev/null 2>&1; then printf "%s" "$video_link" | wl-copy; info "Magnet copied to clipboard."
            elif command -v pbcopy >/dev/null 2>&1; then printf "%s" "$video_link" | pbcopy; info "Magnet copied to clipboard."
            fi
            if ! command -v webtorrent >/dev/null 2>&1; then
                info "To stream torrents in tp: npm install -g webtorrent-cli  (or open the magnet in your torrent client)."
            fi
            exit 0
        fi
        replay="$video_link"
        unset video_link
        [ "$menu_program" != "fzf" ] && wait
        return
    fi
}
