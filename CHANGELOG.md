# Changelog

All notable changes to Tomato Play. Format based on
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.14.0] - 2026-09-27

### Added

- New source: `hianime` — the HiAnime backend (`hianime.at`, overridable with
  `TOMATOPLAY_HIANIME_BASE`), the same source ani-cli relies on. Handles
  server selection, the base64/XOR `otaku-embed-v1` deobfuscation, quality
  variants, bundled subtitles, and the embed Referer the HLS CDN requires.
  With aniwatch's API down, this restores real anime streams to `all`-mode
  searches.

## [1.13.0] - 2026-09-27

### Added

- Watch room: `tp --room [DIR]` hosts a shared-folder sync session (two tiny
  mpv scripts — the host broadcasts position/pause to a state file every 2s;
  guests run `tp --join [DIR]` and mirror seeks + pause). No extra servers or
  tools; just a shared folder, NAS, or the same box.
- Auto-subtitles: when a torrent bundles `.srt/.ass/.vtt` tracks, the matching
  one is auto-attached to the episode (served straight from the torrent).

## [1.12.0] - 2026-09-27

### Added

- Season-pack marathon: `-n` on a multi-episode torrent walks the whole pack
  back-to-back (episode counter in the status line), resuming each file where
  you left off via per-file watch-later slots.

## [1.11.0] - 2026-09-27

### Added

- Cast to TV: `--cast` streams the picked torrent to a nearby Chromecast and
  `--dlna` to a DLNA renderer, via webtorrent's native push (no local player).
- AniList scrobbling: with `TOMATOPLAY_ANILIST_TOKEN` (or `anilist_token` in
  the config), each played episode quietly marks itself watched on AniList in
  the background — your list stays in sync across devices.

## [1.10.1] - 2026-09-27

### Fixed

- Pirate Bay rows carry seeders *and* leechers; the list now shows both
  (`[seeds: 149] [leech: 19]`) so the two can't be confused. The displayed
  seed count was already the real seeder column (the default search page is
  seeder-sorted and that column descends perfectly), but the unambiguous dual
  display settles it either way. The old label said "peers"; it now says
  "seeds".

## [1.10.0] - 2026-09-27

### Added

- New source: `tpb` — torrents via The Pirate Bay mirrors (first host
  configurable with `TOMATOPLAY_TPB_BASE`, with fallbacks). Seeder counts come
  straight from the search page, so `[peers: N]` is real and needs no
  webtorrent probe; playback uses the same magnet/webtorrent/handoff pipeline.
- The torrent section of any picker is sorted by seeder count and shows the top
  10 highest-seeded torrents (tpb rows carry real counts; nyaa rows rank below).
- Torrent streaming serves the picked file with webtorrent and plays it through
  your own mpv/vlc/iina (bypassing webtorrent's flaky built-in player), with a
  pacman snack-bar animation while the stream is buffering.

### Changed

- Torrent picks in the picker are rendered as `[torrent] Title [peers: N]` with
  the tag at the front: live peer counts are fetched in parallel for each
  (bounded by `TOMATOPLAY_TORRENT_LIST_PEEK`, default 8s) and shown in green
  when seeders exist, red when dead; `[torrent]` is in yellow. fzf renders the
  colors; dmenu/rofi show the same info without color. Display chrome is
  stripped before titles reach history/player/filename.

## [1.9.0] - 2026-09-26

### Added

- New source: `nyaa` — anime torrents from nyaa.si (RSS search). Picking a
  torrent streams it straight into mpv via `webtorrent-cli` when installed;
  otherwise it gracefully hands off instead of failing silently — prints the
  magnet, copies it to the clipboard, and saves the `.torrent` into
  `download_dir`. `-d` torrent-downloads via webtorrent. Nyaa results are
  never silently dropped by the `all`-mode playability filter.
- Torrent playback preflights for seeders (`webtorrent downloadmeta`, bounded
  by `TOMATOPLAY_TORRENT_PEEK`, default 30s): a dead/no-seeder torrent
  reports "no reachable seeders" and hands you the magnet instead of hanging
  with nothing on screen.
- Torrent streaming no longer silently waits: the preflight's `.torrent` is fed
  straight to webtorrent (skipping the metadata/`ready` network wait), and the
  player runs in the foreground so webtorrent's own progress stays visible
  instead of being detached to `/dev/null`.
- Torrent picks in the list are rendered as `[torrent] Title [peers: N]` —
  live peer counts checked in parallel (`TOMATOPLAY_TORRENT_LIST_PEEK`,
  default 8s), green when seeders exist and red when dead, with the `[torrent]`
  tag in yellow (fzf shows them in color).

## [1.8.0] - 2026-09-26

### Added

- New source: `bilibili` (bilibili.com, legal). WBI-signed search, season
  episodes, and playback via the episode page (muxed by mpv/iina/yt-dlp).
  Bilibili geo-restricts playback outside allowed regions, so streams fail
  with a clear "geo-restricted — enable a VPN or proxy" message instead of a
  hang.
- `TOMATOPLAY_PROXY` env var: route every provider request through a proxy
  (http/https/socks). Useful for bilibili; a system VPN also works since curl
  follows it.

## [1.7.1] - 2026-09-26

### Fixed

- A dead stream CDN no longer causes a silent ~20s mpv hang and no playback.
  The chosen stream is now reachability-checked (short timeout) before the
  player launches; if a host has gone dark (HTTP 5xx / timeouts / dropped
  connections) it falls through to the next alive server or quality, and if
  every stream is down it says so clearly instead of hanging.
- Continue skipping to the *next* alive server also respects an explicitly
  requested quality first, then falls back for `best`/`worst` like before.

## [1.7.0] - 2026-09-10

### Added

- Local media playback, fully offline: `-f, --file [PATH]`, a bare path
  argument, or a "Play a local file" entry in the home menu. A folder opens a
  picker for the video files inside (`mkv`, `mp4`, `webm`, ...); a file plays
  straight away. Plays reuse the usual player dispatch, keep mpv resume/rewind
  working, and external subtitle files are picked up automatically. Local plays
  don't touch the anime watch history.

## [1.6.1] - 2026-09-09

### Changed

- `-c`/`--continue` no longer asks about audio or a preview: it silently carries
  over the audio track used last time for that show (remembered per show at
  playback, cleared by `-D`) and jumps straight in.

## [1.6.0] - 2026-09-09

### Added

- Per-episode resume with mpv: your position is saved when you quit mid-way,
  and the next play of that episode picks up `resume_back` seconds (default 10)
  earlier. Configurable via the `resume_back` config key or
  `TOMATOPLAY_RESUME_BACK`. `-c`/`--continue` resumes right where you left
  off. Position data lives under the history state dir and is cleared by
  `-D`.

### Fixed

- `-c`/`--continue` jumped straight to the *next* episode, discarding any
  saved position. It now keeps the current episode when a saved position
  exists (so playback truly resumes where you left off), and only advances
  once that episode has been watched to the end.

## [1.5.0] - 2026-09-09

### Added

- After picking an episode (and audio), mpv users are offered a preview
  choice: peek at the first `TOMATOPLAY_PREVIEW_SECS` seconds, or dive
  straight in. Esc skips the peek.

## [1.4.0] - 2026-09-09

### Added

- `~/.config/tomato-play/tomato-playrc`: optional KEY=VALUE config file for
  defaults (mode, quality, player, menu, source, download_dir, log,
  cache_ttl). Precedence is CLI flags > environment > config file; a commented
  starter is planted on first run.
- `-n, --next`: marathon mode — after a show ends, automatically start the next
  episode, rolling on to the finale.
- `--preview`: peek at the first `TOMATOPLAY_PREVIEW_SECS` seconds (default 60)
  of an episode before committing (mpv only).
- `--cache-info`, `--clear-cache`, `--no-cache`: inspect the cache's size and
  entries, wipe it clean, or disable it for a run.
- Shell completions for bash, zsh, and fish, installed alongside the script.

### Fixed

- `--rofi`/`--dmenu`: the no-query "Search:" step no longer opens an empty
  picker that hangs — the query is now read from the terminal regardless of
  menu program.
- Headless non-tty runs no longer override an explicit
  `--rofi`/`--dmenu`/`TOMATOPLAY_MENU` choice with the auto-detected GUI
  picker.

### Added

- `--stats`: watch stats harvested from history — series in the garden,
  episodes logged, approximate watch time, and the marathon champ.
- `--sources`: end-to-end health probe of each source (search, episode list,
  playable stream). Results ride the normal cache so repeats are instant.
- Rotating banner taglines — every run plucks a fresh one-liner off the vine.
- CI: shellcheck lint job on push/PR (error severity) via GitHub Actions.
- Fixed a help text bug where the last usage example was missing its program
  prefix (6 format slots, 5 arguments).

- Interactive home menu when running bare `tp` in a terminal: the mascot
  banner and tagline are shown with a numbered menu (search, continue, watch
  history, trending, or a "Lucky Tomato" surprise pick) below them, replacing
  the raw search prompt for argument-less invocations.

- `-T, --trending`: browse what's currently popular on aniwatch's home page
  without typing a search.
- `-L, --lucky-tomato`: pluck a random *playable* show off the vine by
  shuffling the trending list and probing until the first stream-able title
  is found, then play it immediately.
- **Response cache** (`~/.cache/tomato-play`, configurable via
  `TOMATOPLAY_CACHE_DIR`/`TOMATOPLAY_CACHE_TTL`): episode lists, m3u8 probes and
  the trending list are cached on disk (m3u8 fresh for 30 min, rest a day), so
  repeat searches and `--trending`/`--lucky-tomato` are near-instant and hammer
  the scrapers far less.
- Shared `resolve_title`/`resolve_episodes` steps used by search, history,
  trending and the lucky picker.
- Fixed `--continue`/history: it previously died with "Unknown provider:
  history" because history entries don't store a provider; they now resolve
  through aniwatch.

- `-H, --history` flag to print the watch history (series and last-watched
  episode). Sits alongside the existing `-c/--continue` and `-D/--delete`
  history controls.
- Tomato mascot ASCII-art banner shown at startup and in `--help`, plus
  friendlier copy across prompts, status and error messages.
- Fuzzy search: queries are retried with progressively looser variants
  (symbols stripped, filler words removed, trailing words dropped, per-word and
  4-char prefix fallbacks), then every provider result is ranked by closeness
  to the query so the best match lands on top. Typos and extra words now still
  find the show.

## [1.0.0] - 2026-09-08

### Added

- **Playable streams from aniwatch** via the VidNest backend. Added
  `vidnest_stream`, which resolves aniwatch embed URLs to direct HLS m3u8 links
  by calling the VidNest API, decrypting the custom base64 cipher (custom
  alphabet -> standard base64), and picking the encoded `sources[0].url`.
  Endpoints tried in order: aniwave, megaplay (animehub), anitaku (hianime).
- **Real episode lists with titles** for aniwatch series. The full episode map
  (`ep<TAB>ep<TAB>title`) is derived from the series' episode-1 sidebar, so the
  episode picker shows actual episode numbers and titles instead of a bare
  counter.
- **Audio / subtitle track selection (sub vs dub)**:
  - New flag `-a, --audio sub|dub` and `--dub` shorthand.
  - `TOMATOPLAY_MODE` environment variable for a default track.
  - Interactive picker after choosing an episode when an English dub exists;
    only the tracks actually available for that episode are offered.
  - `change_audio` entry in the playback menu to switch tracks mid-session.
- **Playability pre-filtering of search results**:
  - Entries whose episode list comes back empty are dropped before they appear
    in the picker (previously they failed with "Invalid episode selection").
  - Entries whose streams only resolve to unplayable page-URL fallbacks (or
    gibberish embeds) are dropped. `filter_entries` probes episode 1's stream
    (sub first, then dub) and only keeps entries that return a real stream.
  - Checks run in parallel batches (5 concurrent) to keep the probes fast.
- **mpv playback of HLS URLs whose `.m3u8` only appears in the query string**
  (e.g. `...?t.m3u8`): playback now forces the lavf HLS demuxer so these
  streams decode instead of erroring out.
- Movies/specials of a franchise appear as their own search entries.

### Fixed

- **Wrong show playing (Cowboy Bebop -> One Piece).** Root cause: the
  megaplay (animehub) database serves a corrupt entry for AniList id `1`
  (Cowboy Bebop) that actually contains One Piece content, and the previous
  endpoint order tried megaplay first. The real VidNest player defaults to
  aniwave, so `vidnest_stream` was reordered to aniwave -> megaplay -> anitaku.
  Verified that Cowboy Bebop episodes 1/13/26 and FLCL episode 2 now resolve to
  distinct, per-episode aniwave streams (none matching the One Piece token),
  and that the m3u8 streams decode in mpv.
- **`-a/--audio` not being applied.** `provider_m3u8` passed the selected mode
  as argument 3 to the aniwatch resolver, but the resolver read argument 4, so
  every request silently fell back to subtitled. The resolver signature was
  realigned to read from argument 3.
- **Audio mode never matching the correct track.** The mode matcher looked for
  `-sub`/`-dub` suffixes, but VidNest embed URLs end with `/sub` and `/dub`.
  Matching now uses the slash-separated suffix.
- **Audio menu collapsing to a single choice.** Command substitution strips
  trailing newlines, which merged both audio options onto one line in fzf. The
  menu is now built by storing escaped `\t`/`\n` and expanding with
  `printf %b`, so `Subtitled (Japanese)` and `English Dub` are selectable.
- Removed dead search entries (titles that only ever fail) from the picker.

[1.0.0]: https://github.com/killahtomato/tomato-play/releases/tag/1.0.0