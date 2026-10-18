# Provider adapters: torrent indexers and torrent result presentation.
# Search and episode functions emit tab-separated rows; stream resolvers emit
# quality > URL rows. All functions share the core shell environment.

# ============================================================================
# Provider: nyaa (anime torrents via nyaa.si)
#
# Torrents are a different beast than the streamed sources: picking one hands
# a magnet to webtorrent-cli (streams straight into mpv), or falls back to a
# clean handoff (print magnet, copy to clipboard, save the .torrent) when
# webtorrent-cli isn't installed. Resumption/history apply like any source.
# ============================================================================

nyaa_base="https://nyaa.si"

nyaa_search() {
    _page="$(tp_curl "${nyaa_base}/?page=rss&q=$(printf "%s" "$1" | sed 's| |+|g')&c=1_0")" || return 1
    [ -z "$_page" ] && return 1
    printf "%s" "$_page" | tr '\n' ' ' | sed 's|<item>|\n<item>|g' \
        | sed -nE 's|.*<title>([^<]*)</title>.*<guid[^>]*>https://nyaa\.si/view/([0-9]+)</guid>.*|\2\t\1|p' \
        | sed -e 's|&amp;|\&|g' -e 's|&#34;|"|g' -e "s|&#39;|'|g" \
        | grep -v '^[[:space:]]*$' | head -n 15
}

nyaa_episodes() {
    printf "1\t1\tEpisode 1\n"
}

# Resolve a torrent: emit the magnet as the playable link plus the .torrent
# URL as a sibling line, so playback hands over to webtorrent and the fallback
# can still grab/save the .torrent file.
nyaa_m3u8() {
    _page="$(tp_curl "${nyaa_base}/view/$1")" || return 1
    _mag="$(printf "%s" "$_page" | tr -d '\n' | grep -oE 'magnet:\?xt=urn:btih:[0-9a-fA-F]{40}[^"<]*' | head -n 1 | sed 's|&amp;|\&|g')"
    [ -z "$_mag" ] && { printf '%s\n' "nyaa could not find a magnet for that torrent (it may have been removed)." >&2; return 1; }
    _dl="$(printf "%s" "$_page" | grep -oE '/download/[0-9]+\.torrent' | head -n 1)"
    printf "best >%s\n" "$_mag"
    printf "torrent >%s%s\n" "$nyaa_base" "${_dl:-/download/$1.torrent}"
}

# How many seeders/peers can webtorrent see for a nyaa torrent right now?
# Drives the "[peers: N]" listing annotation. Fast at the cost of a metadata
# fetch; bounded so listings don't grind when trackers are silent.
torrent_peer_count() {
    _pk="$(mktemp -d)" || { echo 0; return 1; }
    _pk_out="$(cd "$_pk" 2>/dev/null && timeout "${TOMATOPLAY_TORRENT_LIST_PEEK:-8}" \
        webtorrent downloadmeta "https://nyaa.si/download/$1.torrent" -o . 2>&1)"
    rm -rf "$_pk"
    printf "%s" "$_pk_out" | grep -oE '[0-9]+ peers' | grep -oE '^[0-9]+' | tail -n 1
}

# ============================================================================
# Provider: tpb (torrents via a Pirate Bay mirror)
#
# The Pirate Bay's domains churn constantly, so a base host is tried first
# (overridable with TOMATOPLAY_TPB_BASE) and a couple of mirrors follow. The
# search table ships seeder/leecher counts, so list-time "[peers: N]" comes
# straight from the page without a webtorrent probe.
# ============================================================================

tpb_hosts="${TOMATOPLAY_TPB_BASE:-https://piratebay.party}"
tpb_hosts="$tpb_hosts https://thepiratebay.net https://tpb.piratebay-proxy.com"

_tpb_page() {
    for _th in $tpb_hosts; do
        _out="$(tp_curl "${_th}/$1" 2>/dev/null)"
        [ -n "$_out" ] && { printf "%s" "$_out"; return 0; }
    done
    return 1
}

tpb_search() {
    _page="$(_tpb_page "search/$(printf "%s" "$1" | sed 's| |+|g')/0/99/0")" || return 1
    # Row cells: uploaded, size ("5.36 GiB"), seeders, leechers. Size is never a
    # bare number, so the first two bare-digit align="right" cells are seeders
    # then leechers. Show both downstream to leave no room for confusion.
    printf "%s" "$_page" | tr '\n' ' ' | sed 's|<td class="vertTh">|\n|g' \
        | sed -nE 's|.*torrent/([0-9]+)/.*title="Details for [^"]*">([^<]*)<.*<td[^>]*align="right"[^>]*>([0-9]+)</td>.{0,4}<td[^>]*align="right"[^>]*>([0-9]+)</td>.*|\1\t\2\t\3\t\4|p' \
        | sed -e 's|&amp;|\&|g' -e "s|&#039;|'|g" -e 's|&quot;|"|g' -e 's|&nbsp;| |g' \
        | grep -v '^[[:space:]]*$' | head -n 30
}

tpb_episodes() {
    printf "1\t1\tEpisode 1\n"
}

tpb_m3u8() {
    _page="$(_tpb_page "torrent/$1/")" || { printf '%s\n' "no Pirate Bay mirror is answering right now." >&2; return 1; }
    _mag="$(printf "%s" "$_page" | tr '\n' ' ' | grep -oE 'magnet:\?xt=urn:btih:[0-9a-fA-F]{40}[^"<]*' | head -n 1)"
    [ -z "$_mag" ] && { printf '%s\n' "could not find a magnet on that Pirate Bay page." >&2; return 1; }
    printf "best >%s\n" "$_mag"
}
