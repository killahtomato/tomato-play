#!/bin/sh

# Exercise the CLI's shared HTTP status helper with a fake selected curl.
set -eu

repo_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
_test_tmp=$(mktemp -d)
trap 'rm -rf "$_test_tmp"' EXIT HUP INT TERM

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_has_line() {
    grep -Fx -- "$1" "$_test_tmp/curl-args" >/dev/null || fail "$2"
}

# Load the function directly from the CLI source so the test exercises the
# production implementation without running its argument-parsing entry point.
sed -n '/^tp_curl_status() {$/,/^}$/p' "$repo_dir/tomatoplay" >"$_test_tmp/tp-curl-status.sh"
[ -s "$_test_tmp/tp-curl-status.sh" ] || fail 'shared status helper exists in the CLI'
. "$_test_tmp/tp-curl-status.sh"

cat >"$_test_tmp/curl" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >"$MOCK_CURL_CAPTURE"
printf '%s\n' "$MOCK_CURL_STATUS"
exit "${MOCK_CURL_EXIT:-0}"
EOF
chmod +x "$_test_tmp/curl"
curl_exe="$_test_tmp/curl"
agent='Tomato Play Test Agent'
cipher_flag=
MOCK_CURL_CAPTURE="$_test_tmp/curl-args"
MOCK_CURL_STATUS=503
export MOCK_CURL_CAPTURE MOCK_CURL_STATUS

TOMATOPLAY_PROXY='socks5h://127.0.0.1:1080'
_status=$(tp_curl_status --range 0-0 -e https://site.example/episode \
    -H 'Origin: https://site.example' https://cdn.example/video.mp4) \
    || fail 'HTTP error responses remain available to caller policy'
[ "$_status" = 503 ] || fail 'status helper returns an HTTP 503 response code'
assert_has_line --proxy 'configured proxy reaches selected curl'
assert_has_line socks5h://127.0.0.1:1080 'proxy value reaches selected curl'
assert_has_line --range 'range request reaches selected curl'
assert_has_line 0-0 'range value reaches selected curl'
assert_has_line -e 'Referer option reaches selected curl'
assert_has_line https://site.example/episode 'Referer reaches selected curl'
assert_has_line 'Origin: https://site.example' 'Origin reaches selected curl'
assert_has_line https://cdn.example/video.mp4 'stream URL reaches selected curl'
assert_has_line --max-time 'probe timeout reaches selected curl'
assert_has_line 8 'probe timeout value reaches selected curl'
assert_has_line -A 'configured user-agent option reaches selected curl'
assert_has_line 'Tomato Play Test Agent' 'configured user agent reaches selected curl'

TOMATOPLAY_PROXY=
_status=$(tp_curl_status https://cdn.example/without-proxy) || fail 'unproxied status request succeeds'
[ "$_status" = 503 ] || fail 'unproxied request returns status'
if grep -Fx -- '--proxy' "$_test_tmp/curl-args" >/dev/null; then
    fail 'proxy option is omitted when no proxy is configured'
fi

MOCK_CURL_EXIT=7
export MOCK_CURL_EXIT
if tp_curl_status https://cdn.example/connection-failure >/dev/null; then
    fail 'transport failures are returned to the caller'
fi

printf 'Core HTTP-helper checks passed.\n'
