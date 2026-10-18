# History persistence, continuation, display, and summary helpers.
# The CLI provides histfile, resume_dir, and the current episode/title state.

# process_hist_entry RESUME_DIR EPISODE SAVED_ID TITLE
# Resolve one saved row and print the next history row without changing the
# active playback source, show, or episode globals.
process_hist_entry() {
    _history_process_resume_dir=$1
    _history_process_episode=$2
    _history_saved_id=$3
    _history_process_title=$4
    _history_process_source=aniwatch
    _history_process_anime_id=$_history_saved_id
    case "$_history_saved_id" in
        anidb:*|aniwatch:*|gogoanime:*|9anime:*|animeplanet:*|anisearch:*|youtube:*|bilibili:*|miruro:*|animegg:*)
            _history_process_source=${_history_saved_id%%:*}
            _history_process_anime_id=${_history_saved_id#*:}
            ;;
    esac
    _history_row_id="${_history_process_source}:${_history_process_anime_id}"
    # If that episode has a saved position, keep it so playback resumes
    # exactly where the user left off instead of jumping to the next one.
    _history_process_resume_key=$(printf "%s-%s" "$_history_process_anime_id" "$_history_process_episode" | tr -c '[:alnum:]' '_')
    if [ -d "$_history_process_resume_dir/$_history_process_resume_key" ] &&
        [ -n "$(find "$_history_process_resume_dir/$_history_process_resume_key" -type f 2>/dev/null)" ]; then
        printf "%s\t%s - episode %s\n" "$_history_row_id" "$_history_process_title" "$_history_process_episode"
        return
    fi
    _history_process_episodes=$(provider_episodes "$_history_process_source" "$_history_process_anime_id") || return 1
    _history_process_next_episode=$(printf '%s\n' "$_history_process_episodes" | awk -F '\t' -v current="$_history_process_episode" \
        '$2 == current { found = 1; next } found { print $2; exit }')
    [ -n "$_history_process_next_episode" ] &&
        printf "%s\t%s - episode %s\n" "$_history_row_id" "$_history_process_title" "$_history_process_next_episode"
}

update_history() {
    _history_file=$1
    _history_source=$2
    _history_anime_id=$3
    _history_episode=$4
    _history_title=$5
    _history_id="$_history_anime_id"
    case "$_history_source" in
        anidb|aniwatch|gogoanime|9anime|animeplanet|anisearch|youtube|bilibili|miruro|animegg)
            _history_id="${_history_source}:${_history_anime_id}"
            ;;
    esac
    _history_match_id="$_history_id"
    if [ "$_history_source" = "aniwatch" ] &&
        ! grep -qF "$(printf '\t%s\t' "$_history_match_id")" "$_history_file" &&
        grep -qF "$(printf '\t%s\t' "$_history_anime_id")" "$_history_file"; then
        # Upgrade an older unprefixed history row in place on its next update.
        _history_match_id="$_history_anime_id"
    fi
    if grep -qF "$(printf '\t%s\t' "$_history_match_id")" "$_history_file"; then
        _history_safe_title=$(printf "%s" "$_history_title" | sed 's|[&\|]|\\&|g')
        sed -E "s|^[^	]+	${_history_match_id}	[^	]+$|${_history_episode}	${_history_id}	${_history_safe_title}|" "$_history_file" >"${_history_file}.new"
    else
        cp "$_history_file" "${_history_file}.new"
        printf "%s\t%s\t%s\n" "$_history_episode" "$_history_id" "$_history_title" >>"${_history_file}.new"
    fi
    mv "${_history_file}.new" "$_history_file"
}

history_view() {
    _history_view_file=$1
    if [ ! -f "$_history_view_file" ] || [ ! -s "$_history_view_file" ]; then
        info "Nothing here yet :\ Go watch something and it'll show up!"
        return 0
    fi
    awk -F '\t' '{ n++; printf "%d. %s (episode %s)\n", n, $3, $1 }' "$_history_view_file"
}

garden_stats() {
    _garden_stats_file=$1
    if [ ! -f "$_garden_stats_file" ] || [ ! -s "$_garden_stats_file" ]; then
        printf "\n    \033[1;32mYour garden's still empty.\033[0m\n"
        printf "    Watch something and your stats will sprout here!\n\n"
        return 0
    fi
    _stats="$(awk -F '\t' '
        { n++; tot += $1; if ($1 > max) { max = $1; champ = $3 } }
        END { printf "%d\n%d\n%s\n%d\n", n, tot, champ, max }
    ' "$_garden_stats_file")"
    _series="$(printf "%s" "$_stats" | sed -n '1p')"
    _eps="$(printf "%s" "$_stats" | sed -n '2p')"
    _champ="$(printf "%s" "$_stats" | sed -n '3p')"
    _max_ep="$(printf "%s" "$_stats" | sed -n '4p')"
    _hours="$(awk -v e="$_eps" 'BEGIN { printf "%.1f", e * 24 / 60 }')"
    printf "\n    \033[1;32mHow's the harvest looking? :3\033[0m\n"
    printf "      Series in the garden : %s\n" "$_series"
    printf "      Episodes logged       : %s\n" "$_eps"
    printf "      Approx. time watched  : %s h\n" "$_hours"
    printf "      Marathon champ        : %s (episode %s)\n" "$_champ" "$_max_ep"
    printf "\n"
}
