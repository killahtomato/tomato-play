# Filter provider candidates to entries that can advance through playback.
# filter_entries SOURCE
# The caller provides provider APIs and _probe_playable; rows arrive on stdin.

filter_entries() {
    _filter_source=$1
    _fdir="$(mktemp -d)" || return 1
    _jobs=0
    while IFS= read -r _check_line; do
        [ -z "$_check_line" ] && continue
        _check_rid="$(printf '%s\n' "$_check_line" | cut -f 1)"
        _check_p="${_check_rid%%:*}"
        case "$_check_p" in
            anidb|aniwatch|gogoanime|9anime|animeplanet|anisearch|youtube|bilibili|miruro|animegg|nyaa|tpb)
                _check_source="$_check_p"
                _check_id="${_check_rid#*:}" ;;
            *) _check_source="$_filter_source" _check_id="$_check_rid" ;;
        esac
        _jobs=$((_jobs + 1))
        {
            _venice="$(provider_episodes "$_check_source" "$_check_id" 2>/dev/null)"
            _vfirst="$(printf '%s\n' "$_venice" | cut -f 1 | head -n 1)"
            if [ -n "$_vfirst" ]; then
                if [ "$_check_source" = "bilibili" ] || [ "$_check_source" = "miruro" ] || [ "$_check_source" = "animegg" ] ||
                    [ "$_check_source" = "nyaa" ] || [ "$_check_source" = "tpb" ]; then
                    # Bilibili may be geo-blocked, Miruro fans out across several
                    # upstreams, and torrents resolve lazily. Check that episodes
                    # exist here and let playback resolve the selected stream.
                    printf "%s\n" "$_check_line"
                elif {
                    provider_m3u8 "$_check_source" "$_check_id" "$_vfirst" sub 2>/dev/null | _probe_playable ||
                    provider_m3u8 "$_check_source" "$_check_id" "$_vfirst" dub 2>/dev/null | _probe_playable
                }; then
                    printf "%s\n" "$_check_line"
                fi
            fi
        } 2>/dev/null >"$_fdir/$_jobs" &
        if [ "$_jobs" -ge "5" ]; then
            wait
            # Collect in numeric order: parallel jobs write numbered files, and
            # a plain glob would scramble 1,10,11,… and break the sort order.
            ls "$_fdir" 2>/dev/null | sort -n | while IFS= read -r _fn; do
                [ -f "$_fdir/$_fn" ] && cat "$_fdir/$_fn"
            done
            _jobs=0
            rm -f "$_fdir"/*
        fi
    done
    wait
    ls "$_fdir" 2>/dev/null | sort -n | while IFS= read -r _fn; do
        [ -f "$_fdir/$_fn" ] && cat "$_fdir/$_fn"
    done
    rm -rf "$_fdir"
}
