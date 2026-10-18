# Selection helpers translate displayed menu rows back into stable data rows.
# The CLI provides menu(), die(), provider_episodes(), and shared flow state.

# nth PROMPT MULTI_SELECT MENU_FLAGS MENU_PROGRAM
# Select rows with data formatted as key<TAB>value<TAB>label. Menu settings are
# passed by the caller so this helper does not depend on CLI configuration
# globals. The displayed index is only a menu token; returned values always
# come from the source row.
nth() {
    _nth_stdin=$(cat -)
    [ -n "$_nth_stdin" ] || return 1
    _nth_count=$(printf '%s\n' "$_nth_stdin" | awk 'END { print NR }')
    if [ "$_nth_count" -eq 1 ]; then
        printf '%s\n' "$_nth_stdin" | awk -F '\t' 'NF >= 3 { print $2 "\t" $3; next } { print }'
        return 0
    fi

    _nth_options=$(printf '%s\n' "$_nth_stdin" | awk -F '\t' '{
        label = (NF >= 3) ? $3 : (NF == 2 ? $2 : $0)
        printf "%d\t%s\n", NR, label
    }')
    _nth_prompt=$1
    _nth_multi=${2:-}
    _nth_choice=$(printf '%s\n' "$_nth_options" | tr '\t' ' ' | menu "${4:-}" "$_nth_prompt" "$_nth_multi" "${3:-}")
    [ -n "$_nth_choice" ] || return 1
    _nth_ids=$(printf '%s\n' "$_nth_choice" | awk '{ print $1 }')

    printf '%s\n' "$_nth_stdin" | awk -F '\t' -v ids="$_nth_ids" '
        BEGIN {
            count = split(ids, selected, "\n")
            for (i = 1; i <= count; i++) keep[selected[i]] = 1
        }
        keep[NR] {
            if (NF >= 3) print $2 "\t" $3
            else print $0
        }
    '
}

# resolve_title RESULTS INDEX SOURCE MENU_FLAGS MENU_PROGRAM
# Resolve a result and update the active source, title, and ID. Selection inputs
# are explicit; those outputs remain shared flow state for the caller.
resolve_title() {
    _rt_results=$1
    _rt_index=$2
    source=$3
    _rt_menu_flags=${4:-}
    _rt_menu_program=${5:-}
    _rt_selected=
    [ "$_rt_index" -eq "$_rt_index" ] 2>/dev/null && _rt_selected=$(printf "%s" "$_rt_results" | sed -n "${_rt_index}p")
    [ -z "$_rt_index" ] && _rt_selected=$(printf "%s" "$_rt_results" | nl -w 2 | sed 's/^[[:space:]]//' | nth "Pick a title: " "" "$_rt_menu_flags" "$_rt_menu_program")
    [ -z "$_rt_selected" ] && die "That pick didn't work out — try again!"
    anime_title=$(printf "%s" "$_rt_selected" | cut -f 2)
    anime_title=$(printf "%s" "$anime_title" | awk '{
        gsub(/\033/, ""); gsub(/\[[0-9;]*m/, "")
        sub(/^\[torrent\] /, ""); sub(/ \[peers: [0-9]*\]$/, "")
        print }')
    anime_id=$(printf "%s" "$_rt_selected" | cut -f 1)
    if [ "$source" = "all" ]; then
        real_source=${anime_id%%:*}
        anime_id=${anime_id#*:}
        case "$real_source" in
            anidb|aniwatch|gogoanime|9anime|animeplanet|anisearch|youtube|bilibili|miruro|animegg|nyaa|tpb) source=$real_source ;;
            *) die "Invalid provider in selection" ;;
        esac
    fi
}

resolve_episodes() {
    _re_source=$1
    _re_anime_id=$2
    _re_requested_episode=$3
    _re_multi=${4:-}
    _re_menu_flags=${5:-}
    _re_menu_program=${6:-}
    ep_no=$_re_requested_episode
    episode_maps=$(provider_episodes "$_re_source" "$_re_anime_id") || exit 1
    ep_list=$(printf '%s' "$episode_maps" | cut -f 2)
    # Normalize legacy history values that stored an opaque episode key.
    case "$ep_no" in
        ''|*[!0-9]*) ;;
        *)
            _mapped_episode=$(printf '%s\n' "$episode_maps" | awk -F '\t' -v requested="$ep_no" \
                '$2 == requested { print $2; found = 1; exit } $1 == requested && legacy == "" { legacy = $2 } END { if (!found && legacy != "") print legacy }')
            [ -n "$_mapped_episode" ] && ep_no=$_mapped_episode
            ;;
    esac
    [ -z "$ep_no" ] && ep_no=$(select_episode_numbers "$episode_maps" "$_re_multi" "$_re_menu_flags" "$_re_menu_program")
    if [ -z "$ep_no" ]; then
        die "Couldn't find that episode, sorry!"
    fi
    return 0
}

# Show user-facing episode numbers and titles, but return only episode numbers.
select_episode_numbers() {
    _sen_episode_maps=$1
    _sen_multi=${2:-}
    _sen_menu_flags=${3:-}
    printf '%s\n' "$_sen_episode_maps" | awk -F '\t' 'NF >= 3 { print $2 "\t" $2 "\t" $3 }' \
    | nth "Pick an episode: " "$_sen_multi" "$_sen_menu_flags" "${4:-}" | cut -f 1
}

# episode_key_for_number EPISODE_MAPS DISPLAY_NUMBER
# Map a display episode number to the provider's opaque stream key.
episode_key_for_number() {
    printf '%s\n' "$1" | awk -F '\t' -v number="$2" '$2 == number { print $1; exit }'
}
