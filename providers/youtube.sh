# Provider adapter: youtube.com.
# ============================================================================
# Provider: youtube.com
# ============================================================================

youtube_base="https://www.youtube.com"

youtube_search() {
    dep_ch_failover "yt-dlp" >/dev/null || { printf '%s\n' "youtube provider requires yt-dlp" >&2; return 1; }
    yt-dlp --flat-playlist --print "%(id)s\t%(title)s" "ytsearch20:$(printf "%s" "$1" | sed 's| |+|g')" 2>/dev/null | sed 's/\\t/\t/g' || return 1
}

youtube_episodes() {
    printf "1\t1\tSelected video\n"
}

youtube_m3u8() {
    dep_ch_failover "yt-dlp" >/dev/null || return 1
    _formats="$(yt-dlp -F "https://www.youtube.com/watch?v=$1" 2>/dev/null | grep -E '^[0-9]+ +mp4 +[0-9]+x' | grep -vE 'audio' | sed -E 's|.* +([0-9]+)x([0-9]+) +.*|\2|' | sort -gr -u)"
    [ -z "$_formats" ] && printf "best >https://www.youtube.com/watch?v=%s\n" "$1" && return 0
    for _res in $_formats; do
        printf "%sp >https://www.youtube.com/watch?v=%s\n" "$_res" "$1"
    done
}
