# Provider adapter: hianime (HiAnime backend).
#
# HiAnime serves server-rendered HTML for search/episodes plus a JSON server
# list; the stream lives behind a ZokoAnime embed whose config is base64(XOR
# "otaku-embed-v1"). The HLS CDN requires the embed Referer on every request,
# so the referrer is resolved by a helper the core calls directly, and any
# bundled subtitle is exposed the same way.

hianime_base="${TOMATOPLAY_HIANIME_BASE:-https://hianime.at}"

hianime_deobfuscate() {
    _hdb_bytes="$(printf "%s" "$1" | base64 -d 2>/dev/null | od -v -An -tu1)"
    set -- 111 116 97 107 117 45 101 109 98 101 100 45 118 49
    _hdb_out=""
    for _hdb_b in $_hdb_bytes; do
        _hdb_c=$((_hdb_b ^ $1))
        _hdb_out="${_hdb_out}\\0$((_hdb_c / 64))$(((_hdb_c / 8) % 8))$((_hdb_c % 8))"
        set -- "$@" "$1"
        shift
    done
    printf "%b" "$_hdb_out"
}

hianime_search() {
    _page="$(tp_curl "${hianime_base}/search?keyword=$(printf "%s" "$1" | sed 's| |+|g')")" || return 1
    [ -z "$_page" ] && return 1
    printf "%s" "$_page" | sed '/id="main-sidebar"/,$d' | tr '\n' ' ' \
        | sed 's|<div class="film-detail">|\n<div class="film-detail">|g' \
        | sed -nE 's|.*<h3 class="film-name">[[:space:]]*<a href="[^"]*/([^"/]*)"[[:space:]]*title="([^"]*)".*|\1\t\2|p' \
        | sed -e "s|&#039;|'|g" -e 's|&quot;|"|g' -e "s|&amp;|\&|g" \
        | grep -v '^[[:space:]]*$' | head -n 10
}

hianime_episodes() {
    _page="$(tp_curl "${hianime_base}/api/theme/episode/list/${1##*-}")" || return 1
    [ -z "$_page" ] && return 1
    printf "%s" "$_page" | sed 's|\\"|"|g' | sed 's|data-number="|\ndata-number="|g' \
        | sed -nE 's|data-number="([0-9]+)".*data-id="([0-9]+)".*|\2\t\1\tEpisode \1|p'
}

# Resolve the ZokoAnime embed for an episode id and print the deobfuscated JSON.
hianime_embed_json() {
    _hij_srv="$(tp_curl "${hianime_base}/api/theme/episode/servers?episodeId=$1" | sed 's|\\"|"|g; s|server-item|\nserver-item|g')"
    [ -z "$_hij_srv" ] && return 1
    _hij_hash="$(printf "%s" "$_hij_srv" | sed -nE 's|.*data-type="sub".*data-server-name="ZokoAnime".*data-hash="([^"]*)".*|\1|p' | head -n 1)"
    [ -z "$_hij_hash" ] && return 1
    _hij_embed="$(printf "%s" "$_hij_hash" | base64 -d 2>/dev/null)"
    [ -z "$_hij_embed" ] && return 1
    _hij_blob="$(tp_curl "$_hij_embed" | sed -nE 's|.*window\.__P="([^"]*)".*|\1|p' | head -n 1)"
    [ -z "$_hij_blob" ] && return 1
    hianime_deobfuscate "$_hij_blob"
}

# The embed host origin, sent as Referer/Origin so the HLS CDN serves.
hianime_referrer_for_episode() {
    _hrf_srv="$(tp_curl "${hianime_base}/api/theme/episode/servers?episodeId=$1" | sed 's|\\"|"|g; s|server-item|\nserver-item|g')"
    [ -z "$_hrf_srv" ] && return 1
    _hrf_hash="$(printf "%s" "$_hrf_srv" | sed -nE 's|.*data-type="sub".*data-server-name="ZokoAnime".*data-hash="([^"]*)".*|\1|p' | head -n 1)"
    [ -z "$_hrf_hash" ] && return 1
    _hrf_embed="$(printf "%s" "$_hrf_hash" | base64 -d 2>/dev/null)"
    [ -z "$_hrf_embed" ] && return 1
    printf '%s' "$_hrf_embed" | sed -E 's|^(https?://[^/]*).*|\1/|'
}

# Bundled default subtitle track, if the episode ships one.
hianime_sub_for_episode() {
    _hsf_json="$(hianime_embed_json "$1")" || return 1
    printf '%s' "$_hsf_json" | sed 's|.*"subtitles":\[||; s|\].*||; s|},{|}\n{|g' \
        | grep -m1 '"default":true' | sed -nE 's|.*"src":"([^"]*)".*|\1|p'
}

hianime_m3u8() {
    _hjm_json="$(hianime_embed_json "$2")" || return 1
    _hjm_master="$(printf "%s" "$_hjm_json" | sed -nE 's|.*"src":"([^"]+\.m3u8[^"]*)".*|\1|p' | head -n 1)"
    [ -z "$_hjm_master" ] && return 1
    _hjm_referer="$(hianime_referrer_for_episode "$2")"
    [ -z "$_hjm_referer" ] && return 1
    # Master playlist lists relative quality variants; fetch it with the referer.
    _hjm_body="$($curl_exe -sL -A "$agent" --max-time 15 $cipher_flag $_px_flag -e "$_hjm_referer" "$_hjm_master" 2>/dev/null)" || return 1
    printf "%s" "$_hjm_body" | awk '
        /^#EXT-X-STREAM-INF/ { if (match($0, /RESOLUTION=[0-9]+x([0-9]+)/, m)) q = m[1]; next }
        NF { if (q != "") { print q "p >" $0; q = "" } }' \
        | sed "s| >| >${_hjm_master%/*}/|; s| >${_hjm_master%/*}/http| >http|" | sort -g -r -s
}

hianime_audio_modes() {
    _ham_page="$(tp_curl "${hianime_base}/api/theme/episode/list/${1##*-}")" || return 1
    _ham_eid="$(printf "%s" "$_ham_page" | sed 's|\\"|"|g' | sed 's|data-number="|\ndata-number="|g' \
        | sed -nE "s|data-number=\"${2}\".*data-id=\"([0-9]+)\".*|\1|p" | head -n 1)"
    [ -z "$_ham_eid" ] && return 1
    _ham_srv="$(tp_curl "${hianime_base}/api/theme/episode/servers?episodeId=$_ham_eid" | sed 's|\\"|"|g')"
    printf "%s" "$_ham_srv" | grep -q 'data-type="sub"' && printf 'sub\n'
    printf "%s" "$_ham_srv" | grep -q 'data-type="dub"' && printf 'dub\n'
}
