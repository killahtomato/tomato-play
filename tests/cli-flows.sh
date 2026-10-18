#!/bin/sh

# Offline integration checks for CLI arguments, local files, search, and history.
set -eu

repo_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
_test_tmp=$(mktemp -d)
trap 'rm -rf "$_test_tmp"' EXIT HUP INT TERM
_test_bin="$_test_tmp/bin"
mkdir -p "$_test_bin"

cat >"$_test_bin/curl" <<'EOF'
#!/bin/sh
printf '200'
EOF
for _curl_name in curl_firefox135 curl_chrome136 curl_chrome116 curl_ff117; do
    ln -s curl "$_test_bin/$_curl_name"
done

cat >"$_test_bin/yt-dlp" <<'EOF'
#!/bin/sh
case "$1" in
    --flat-playlist) printf 'yt-video\tIntegration Demo\n' ;;
    -F) printf '18 mp4 1280x720 500k\n' ;;
    *) exit 0 ;;
esac
EOF

cat >"$_test_bin/dmenu" <<'EOF'
#!/bin/sh
IFS= read -r _first || exit 1
printf '%s\n' "$_first"
EOF
chmod +x "$_test_bin/curl" "$_test_bin/yt-dlp" "$_test_bin/dmenu"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_has() {
    printf '%s\n' "$1" | grep -Fq -- "$2" || fail "$3"
}

run_cli() {
    env \
        PATH="$_test_bin:$PATH" \
        TERM=xterm \
        XDG_CONFIG_HOME="$_test_tmp/config" \
        XDG_STATE_HOME="$_test_tmp/state" \
        XDG_CACHE_HOME="$_test_tmp/cache" \
        TOMATOPLAY_PLAYER=debug \
        TOMATOPLAY_MENU=dmenu \
        TOMATOPLAY_LOG=0 \
        "$repo_dir/tomatoplay" "$@"
}

_media_dir="$_test_tmp/media files"
mkdir -p "$_media_dir"
_local_one="$_media_dir/01 pilot episode.mkv"
_local_two="$_media_dir/02 next episode.mp4"
: >"$_local_one"
: >"$_local_two"

_positional_output=$(run_cli "$_local_one") || fail 'positional media path is accepted'
assert_has "$_positional_output" "Selected link:" 'positional path reaches local playback'
assert_has "$_positional_output" "$_local_one" 'positional path with spaces is preserved'

_flag_output=$(run_cli --file "$_local_one") || fail '--file path is accepted'
assert_has "$_flag_output" "$_local_one" '--file reaches local playback'

_folder_output=$(run_cli --file "$_media_dir") || fail 'local folder selection succeeds'
assert_has "$_folder_output" "$_local_one" 'folder menu selects the first sorted media file'

_search_output=$(run_cli --source youtube --episode 1 --select-nth 1 'integration demo') \
    || fail 'explicit source search and selection succeeds'
assert_has "$_search_output" 'https://www.youtube.com/watch?v=yt-video' 'selected YouTube source reaches playback'
_histfile="$_test_tmp/state/tomato-play/tp-hsts"
grep -Fq "$(printf '1\tyoutube:yt-video\tIntegration Demo')" "$_histfile" \
    || fail 'CLI playback writes the selected provider into history'

_history_output=$(run_cli --history) || fail '--history display succeeds'
assert_has "$_history_output" '1. Integration Demo (episode 1)' 'history command shows saved CLI playback'

_resume_key=$(printf '%s-%s' yt-video 1 | tr -c '[:alnum:]' '_')
mkdir -p "$_test_tmp/state/tomato-play/resume/$_resume_key"
: >"$_test_tmp/state/tomato-play/resume/$_resume_key/watch_later"
_continue_output=$(run_cli --continue) || fail '--continue restores and plays the saved source'
assert_has "$_continue_output" 'Audio: sub (from last time)' 'continue restores the prior audio mode'
assert_has "$_continue_output" 'https://www.youtube.com/watch?v=yt-video' 'continue resolves the saved provider ID'

_arg_status=0
_arg_output=$(run_cli --episode 2>&1) || _arg_status=$?
[ "$_arg_status" -eq 1 ] || fail 'missing option argument exits with an error'
assert_has "$_arg_output" 'missing argument' 'missing option argument has a readable diagnostic'

printf 'CLI flow checks passed.\n'
