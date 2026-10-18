# Miruro adapter backed by the community Miruro API.
#
# This API exposes AniList search, Miruro provider episode lists, and direct
# stream URLs. Its endpoint can be overridden with TOMATOPLAY_MIRURO_API.

miruro_api_root() {
    _miruro_root="${TOMATOPLAY_MIRURO_API:-https://api.hiyori.tv}"
    printf '%s' "${_miruro_root%/}"
}

miruro_require_jq() {
    command -v jq >/dev/null 2>&1 || {
        printf '%s\n' 'Miruro source requires jq to read its API responses.' >&2
        return 1
    }
}

miruro_episode_data() {
    _miruro_data_key="$(_cpe_key 'miruro-episode-data-v1' "$1")"
    if _miruro_data="$(cache_read "$_miruro_data_key" 360)"; then
        printf '%s' "$_miruro_data"
        return 0
    fi
    _miruro_data="$(tp_curl "$(miruro_api_root)/episodes/$1" -H 'Accept: application/json')" || return 1
    cache_write "$_miruro_data_key" "$_miruro_data"
    printf '%s' "$_miruro_data"
}

miruro_search() {
    miruro_require_jq || return 1
    _miruro_query=$(printf '%s' "$1" | jq -sRr @uri) || return 1
    _miruro_url="$(miruro_api_root)/search?query=${_miruro_query}&page=1&per_page=10"
    _miruro_response="$(tp_curl "$_miruro_url" -H 'Accept: application/json')" || return 1
    printf '%s' "$_miruro_response" | jq -er '
        .results[]?
        | select(.id != null)
        | [(.id | tostring), (.title.english // .title.romaji // .title.native // .title // .name // "")]
        | @tsv
    ' 2>/dev/null | head -n 10
}

# Miruro combines several upstream catalogs. Use the upstream with the most
# subtitled episodes for the menu, then keep episode numbers as stable keys so
# stream resolution can try every Miruro upstream for that number.
miruro_episodes() {
    miruro_require_jq || return 1
    _miruro_response="$(miruro_episode_data "$1")" || return 1
    _miruro_rows=$(printf '%s' "$_miruro_response" | jq -er '
        .providers as $providers
        | ([$providers | to_entries[]
            | {episodes: (.value.episodes.sub // [])}
            | select(.episodes | length > 0)]) as $sub
        | if ($sub | length) > 0 then $sub
          else [$providers | to_entries[]
            | {episodes: (.value.episodes.dub // [])}
            | select(.episodes | length > 0)]
          end
        | if length == 0 then empty
          else max_by(.episodes | length).episodes[]
            | select(.id != null and .number != null)
            | [(.number | tostring), (.number | tostring), (.title // ("Episode " + (.number | tostring)))]
            | @tsv
          end
    ' 2>/dev/null) || return 1
    [ -n "$_miruro_rows" ] || return 1
    printf '%s\n' "$_miruro_rows"
}

miruro_m3u8() {
    miruro_require_jq || return 1
    _miruro_response="$(miruro_episode_data "$1")" || return 1
    _miruro_episode_ids=$(printf '%s' "$_miruro_response" | jq -r \
        --arg mode "$3" --arg number "$2" '
        .providers // {} | to_entries[]
        | .value.episodes[$mode][]?
        | select((.number | tostring) == $number)
        | .id // empty
    ' 2>/dev/null) || return 1
    [ -n "$_miruro_episode_ids" ] || {
        printf 'Miruro has no %s stream listed for episode %s.\n' "$3" "$2" >&2
        return 1
    }

    _miruro_stream_count=0
    while IFS= read -r _miruro_episode_id; do
        case "$_miruro_episode_id" in
            watch/*) ;;
            *) continue ;;
        esac
        _miruro_response="$(tp_curl "$(miruro_api_root)/$_miruro_episode_id" -H 'Accept: application/json' 2>/dev/null)" || continue
        _miruro_streams=$(printf '%s' "$_miruro_response" | jq -r '
            .streams[]?
            | select((.type // "" | ascii_downcase) == "hls"
                or (.type // "" | ascii_downcase) == "m3u8"
                or (.type // "" | ascii_downcase) == "mp4"
                or (.type // "" | ascii_downcase) == "dash")
            | select((.url // "") | startswith("http://") or startswith("https://"))
            | [(.quality // .resolution.height // "best" | tostring), .url]
            | @tsv
        ' 2>/dev/null) || continue
        [ -n "$_miruro_streams" ] || continue
        while IFS="$(printf '\t')" read -r _miruro_quality _miruro_url; do
            [ -n "$_miruro_url" ] || continue
            printf '%s >%s\n' "$_miruro_quality" "$_miruro_url"
            _miruro_stream_count=$((_miruro_stream_count + 1))
        done <<EOF
$_miruro_streams
EOF
    done <<EOF
$_miruro_episode_ids
EOF
    [ "$_miruro_stream_count" -gt 0 ] || {
        printf 'Miruro could not find a direct playable stream for episode %s.\n' "$2" >&2
        return 1
    }
}
