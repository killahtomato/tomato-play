# Changelog

All notable changes to Tomato Play. Format based on
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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