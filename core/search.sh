# Search query fallback and ranking. The CLI supplies provider_search,
# provider_peer_count, and render_torrent_line when fuzzy_search is called.

# Generate progressively looser search queries (best first) so a typo or extra
# words in the user's input can still find the right show.
search_relax() {
    _sq="$1"
    printf "%s\n" "$_sq"
    _snorm="$(printf "%s" "$_sq" | sed 's|[^A-Za-z0-9 ]| |g; s|[[:space:]][[:space:]]*| |g; s|^ ||; s| $||')"
    [ -n "$_snorm" ] && [ "$_snorm" != "$_sq" ] && printf "%s\n" "$_snorm"
    _sstop="$(printf "%s" "$_snorm" | awk '{ for (i = 1; i <= NF; i++) { w = $i; if (w !~ /^(the|a|an|of|to|and|movie|movies|full|sub|dub|season|part|ep|episode|show|series)$/) { if (l) printf " "; printf "%s", w; l = 1 } } }')"
    [ -n "$_sstop" ] && [ "$_sstop" != "$_snorm" ] && printf "%s\n" "$_sstop"
    _sdw="$(printf "%s" "$_sstop" | sed -E 's|[[:space:]][^[:space:]]*$||')"
    [ -n "$_sdw" ] && [ "$_sdw" != "$_sstop" ] && printf "%s\n" "$_sdw"
    _sfw="$(printf "%s" "$_sstop" | sed -E 's|[[:space:]].*$||')"
    [ -n "$_sfw" ] && [ "$_sfw" != "$_sstop" ] && printf "%s\n" "$_sfw"
    for _fword in $_sstop; do
        case "${#_fword}" in
            0|1|2|3|4) continue ;;
        esac
        printf "%s\n" "$_fword"
        printf "%s\n" "$(printf "%s" "$_fword" | cut -c1-4)"
    done
}

# Order provider results by title similarity to the user's query.
fuzzy_rank() {
    awk -v query="$1" '
        function norm(s) {
            gsub(/[^A-Za-z0-9 ]/, " ", s)
            gsub(/[ ]+/, " ", s)
            return tolower(s)
        }
        BEGIN { q = norm(query); nq = split(q, qw, " ") }
        {
            title = $0
            sub(/^[^\t]*\t/, "", title)
            t = norm(title)
            score = 0
            nt = split(t, tw, " ")
            for (i = 1; i <= nq; i++) {
                if (qw[i] == "") continue
                best = 0
                for (j = 1; j <= nt; j++) {
                    if (tw[j] == qw[i]) {
                        best = 6 + length(qw[i])
                    } else if (length(qw[i]) >= 3 && length(tw[j]) >= 3) {
                        if (substr(tw[j], 1, length(qw[i])) == qw[i]) v = 3 + length(qw[i])
                        else if (substr(qw[i], 1, length(tw[j])) == tw[j]) v = 3 + length(tw[j])
                        else v = 0
                        if (v > best) best = v
                    }
                }
                score += best
            }
            if (index(t, q)) score += 6
            cl = (length(q) < length(t)) ? length(q) : length(t)
            for (p = 1; p <= cl && substr(q, p, 1) == substr(t, p, 1); p++) score += 1
            dl = length(t) - length(q); if (dl < 0) dl = -dl
            if (dl > 8) dl = 8
            printf "%d\t%s\n", score - dl, $0
        }
    '
}

# Try progressively looser queries, merge unique results, and rank them.
fuzzy_search() {
    _fs_src="$1"
    _fs_query="$2"
    _fs_tried=""
    _fs_found=""
    _fs_cands="$(mktemp)" || return 1
    search_relax "$_fs_query" >"$_fs_cands"
    while IFS= read -r _fs_cand <&3; do
        [ -n "$_fs_cand" ] || continue
        if printf "%s\n" "$_fs_tried" | grep -qxF "$_fs_cand"; then continue; fi
        _fs_tried="$(printf "%s\n%s" "$_fs_tried" "$_fs_cand")"
        _fs_r="$(provider_search "$_fs_src" "$_fs_cand" 2>/dev/null)"
        if [ -n "$_fs_r" ]; then
            _fs_found="$(printf "%s\n%s" "$_fs_found" "$_fs_r" | grep -v '^$')"
            break
        fi
    done 3<"$_fs_cands"
    rm -f "$_fs_cands"
    [ -z "$_fs_found" ] && return 0
    _fs_alltor="0"
    case "$_fs_src" in nyaa | tpb) _fs_alltor="1" ;; esac
    _fs_out="$(printf "%s\n" "$_fs_found" | grep -v '^$' | sort -u | fuzzy_rank "$_fs_query" |
        sort -t "$(printf '\t')" -k1,1 -nr | cut -f 2- | grep -v '^$' | awk -v all="$_fs_alltor" -v source="$_fs_src" '
            # Streaming results first (relevance order), torrents always at the
            # bottom so they never hijack the picks. In all mode, keep the top
            # ten from each source so stale providers cannot crowd out a
            # lower-ranked source before the playability filter checks it.
            /^(nyaa|tpb):/ || all == 1 { nt++; if (nt <= 30) t = t $0 "\n"; next }
            {
                provider = source
                if (source == "all") {
                    provider = $1
                    sub(/:.*/, "", provider)
                }
                ns[provider]++
                if (ns[provider] <= 10) s = s $0 "\n"
            }
            END { printf "%s%s", s, t }')"
    [ "$_fs_alltor" != "1" ] && printf "%s\n" "$_fs_out" | grep -vE '^(nyaa|tpb):' | grep -v '^$'
    # Torrents: seeder count first, then annotate the top ten with peer counts.
    _fs_tr="$(printf "%s\n" "$_fs_out" | {
        if [ "$_fs_alltor" = "1" ]; then
            grep -v '^$'
        else
            grep -E '^(nyaa|tpb):' || :
        fi
    })"
    _fs_tr="$(printf '%s\n' "$_fs_tr" | sort -t "$(printf '\t')" -k3,3 -nr -s | head -n 10)"
    if [ -n "$_fs_tr" ]; then
        _fs_td="$(mktemp -d)" || return 1
        _fs_tl="$(mktemp)" || return 1
        printf "%s\n" "$_fs_tr" >"$_fs_tl"
        _fs_i=0
        exec 3<"$_fs_tl"
        while IFS= read -r _fs_tline <&3; do
            _fs_i=$((_fs_i + 1))
            {
                _fs_id="$(printf "%s" "$_fs_tline" | cut -f 1 | sed 's|^\(nyaa\|tpb\):||')"
                _fs_pc="$(printf "%s" "$_fs_tline" | cut -f 3)"
                if [ -z "$_fs_pc" ]; then
                    if command -v webtorrent >/dev/null 2>&1; then
                        _fs_pc="$(provider_peer_count nyaa "$_fs_id")"
                    fi
                    [ -n "$_fs_pc" ] || _fs_pc=0
                fi
                render_torrent_line "$_fs_tline" "$_fs_pc"
            } >"$_fs_td/$_fs_i" &
        done
        exec 3<&-
        rm -f "$_fs_tl"
        wait
        ls "$_fs_td" 2>/dev/null | sort -n | while IFS= read -r _fs_fn; do
            [ -f "$_fs_td/$_fs_fn" ] && cat "$_fs_td/$_fs_fn"
        done
        rm -rf "$_fs_td"
    fi
}
