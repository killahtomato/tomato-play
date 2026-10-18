# Provider interface

`tomatoplay` sources the files in this directory into its POSIX shell process.
Provider implementation functions are adapters; the core should call only the
public dispatch functions in `dispatch.sh`.

## Public functions

### `provider_search PROVIDER QUERY`

Print one result per line with `content_id<TAB>title` in the first two fields.
A source-specific search returns its native content ID. `provider_search all
QUERY` prefixes each ID with its source, such as `aniwatch:123<TAB>Example
title`, so later calls can route the selection back to the same provider.
Torrent search rows may add seed and leech counts in fields three and four.

### `provider_episodes PROVIDER CONTENT_ID`

Print one episode per line as
`episode_key<TAB>episode_number<TAB>title`. The episode key is the value used
to request a stream; the number is the user-facing and ordering number. Keep
those fields separate even when a provider uses the same value for both.

### `provider_m3u8 PROVIDER CONTENT_ID EPISODE_KEY MODE`

`EPISODE_KEY` is the first field returned by `provider_episodes`. Print stream
choices as `quality > URL`, one per line. Torrent sources may
include a `best > magnet:...` row and a companion `torrent > https://...` row.
`MODE` is `sub` or `dub`; callers pass `sub` when no mode was selected.

### `provider_audio_modes PROVIDER CONTENT_ID EPISODE_NUMBER`

Print supported audio modes (`sub` and/or `dub`), one per line. A provider
without selectable modes returns nonzero and no output.

### `provider_trending PROVIDER`

Print `content_id<TAB>title` rows when the provider has a trending feed.
Providers without a feed return nonzero and no output.

### `provider_peer_count PROVIDER CONTENT_ID`

Print a nonnegative peer count when supported. Unsupported providers return
nonzero and no output.

### `provider_is_direct_stream URL`

Return zero when the URL is directly playable, and nonzero when it is a
provider watch/embed page or is not a supported URL. Magnet links are
considered directly playable.

## Adapter rules

- Adapter inputs are positional arguments: search gets a query; episodes gets
  a content ID; stream resolution gets content ID, episode key, and mode.
- Write machine-readable results to stdout only. Send diagnostics to stderr.
- Return zero when the operation succeeds and nonzero when it fails. Do not call
  `exit` or `die` from an adapter; that would terminate the caller instead of
  letting dispatch report a provider failure.
- Do not change core flow variables such as `source`, `anime_id`, `ep_no`,
  `episode_maps`, `video_link`, or `mode`. Keep provider-specific state under
  provider-prefixed names.
- Shared services available to adapters include `tp_curl`,
  `tp_curl_status`, `dep_ch_failover`, and `warn`. `tp_curl` returns a body
  only for successful 2xx responses. `tp_curl_status` prints the final HTTP
  status without treating 4xx or 5xx as a transport failure, for callers that
  need source-specific status policy. Both use the selected `curl_exe`, user
  agent, TLS settings, and `TOMATOPLAY_PROXY`. The request context is also
  available as `curl_exe`, `agent`, `cipher_flag`, and `_px_flag`. Dispatch
  owns cache reads/writes.
- Keep these public functions stable: `provider_search`, `provider_episodes`,
  `provider_m3u8`, `provider_audio_modes`, `provider_trending`,
  `provider_peer_count`, and `provider_is_direct_stream`. Add provider support
  by implementing its adapter functions and registering the capability in
  `dispatch.sh`.

The AnimeGG adapter scrapes AnimeGG's public HTML catalog, extracts the
embedded MP4 URL, and retains its own player page as a browser fallback. The
Miruro adapter uses jq and a
community-maintained Miruro API by default;
`TOMATOPLAY_MIRURO_API` can point it at another compatible API base.
