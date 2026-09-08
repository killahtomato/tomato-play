# Changelog

All notable changes to Tomato Play. Format based on
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added

- `-H, --history` flag to print the watch history (series and last-watched
  episode). Sits alongside the existing `-c/--continue` and `-D/--delete`
  history controls.
- Tomato mascot ASCII-art banner shown at startup and in `--help`, plus
  friendlier copy across prompts, status and error messages.

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