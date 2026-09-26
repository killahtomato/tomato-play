# Tomato Play

A CLI tool to browse and watch anime, movies, and TV series from multiple sources.

## Features

- Interactive home menu when you run `tp` with no arguments
- `tp --stats`: watch stats (series, episodes, time, marathon champ)
- `tp --sources`: health check for which sources work right now
- Rotating tomato taglines under the banner :3
- `tp -n`: marathon mode — keeps rolling into the next episode
- `tp -c` resumes where you left off mid-episode (mpv), rewinding
  `resume_back` seconds (default 10)
- `tp --preview`: peek at the first seconds of an episode (mpv)
- `tp -f` / `tp local.mp4`: play local files and folders, fully offline
- Config file at `~/.config/tomato-play/tomato-playrc`
- Shell completions for bash, zsh, and fish
- Cache tools: `--cache-info`, `--clear-cache`, `--no-cache`
- Search and stream from multiple anime sources
- Support for anime, movies, and TV series
- Quality selection
- Download support
- Watch history
- Syncplay support for watching with friends

## Supported Sources

| Source | URL | Content | Status |
|--------|-----|---------|--------|
| anidb | anidb.app | Anime | Full (primary)** |
| aniwatch | aniwatch.cx | Anime | Full (playable streams) |
| gogoanime | gogoanime.by | Anime | Search + episodes* |
| 9anime | 9anime.tech | Anime | Search + episodes* |
| anime-planet | anime-planet.com | Anime (legal info) | Search only (no streams) |
| anisearch | anisearch.com | Anime aggregator | Search disabled (JS-only) |
| asiancrush | asiancrush.com | Movies/TV | Planned |
| midnightpulp | midnightpulp.com | Movies/TV | Planned |
| youtube | youtube.com | General video | Full |
| bilibili | bilibili.com | Anime (legal) | Full (geo-restricted outside Asia; use `TOMATOPLAY_PROXY`/VPN)

> **Note:**
> - `*` Sources whose video streams load via JavaScript (often Cloudflare-protected)
>   only expose an obfuscated embed URL that curl-based tooling cannot play.
> - `**` anidb.app is the same fully-working source used by ani-cli. **Please note it
>   is currently down (HTTP 503)** while it relocates to a new domain.
> - **aniwatch.cx (and YouTube) work fully today**: `tp -s aniwatch "naruto"` resolves
>   the encrypted VidNest embed into a direct HLS URL, which mpv streams natively.
> - `all` mode defaults to the first playable source (aniwatch), then gogoanime,
>   9anime, and anidb (when it recovers).

## Installation

### From Source

```bash
git clone https://github.com/killahtomato/tomato-play.git
cd tomato-play
# Run the installer (installs tomatoplay and the tp alias)
sudo ./install.sh
# Or manually:
# sudo install -m755 tomatoplay /usr/local/bin/tomatoplay
# sudo ln -sf tomatoplay /usr/local/bin/tp
```

Set `PREFIX` to install elsewhere (defaults to `/usr/local`):
`sudo PREFIX=/opt ./install.sh`

### Dependencies

- `grep`, `sed`, `curl`
- `mpv` or `vlc` (video player)
- `yt-dlp` or `ffmpeg` (for downloads)
- `fzf` (interactive menu)
- `patch` (for self-update)

## Usage

```bash
# Home menu (search, continue, history, trending, surprise me, local files :3)
tp

# Basic search
tp "one piece"

# Search all sources (default)
tp --source all "naruto"

# Source-specific search
tp -s anidb "naruto"
tp -s gogoanime "naruto"
tp -s youtube "attack on titan trailer"

# Episode selection
tp -e 5 "one piece"
tp -e 1-10 "naruto"

# Quality
tp -q 1080 "anime name"

# Player selection
tp --vlc "anime name"

# Continue watching
tp -c
# (resumes where you left off — set resume_back / TOMATOPLAY_RESUME_BACK for
#  how many seconds to rewind, default 10)

# Local media — fully offline, no search needed
tp -f ~/videos/my-show/          # folder -> pick a file inside
tp ~/videos/ep01.mkv             # bare path plays straight away

# Marathon mode (auto-next episode)
tp -n "one piece"

# Peek at the first 60s of an episode (mpv)
tp --preview "one piece"

# Cache housekeeping
tp --cache-info
tp --clear-cache

# Download
tp -d "naruto" -e 1-10

# Version
tp -V

# Help
tp -h
```

## Options

```
-s, --source SOURCE    Specify source (all, anidb, aniwatch, gogoanime, 9anime, animeplanet, anisearch, youtube, bilibili)
TOMATOPLAY_PROXY       Route requests through a proxy (e.g. socks5h://127.0.0.1:1080); needed for bilibili outside Asia
-c, --continue         Continue watching from history
-f, --file [PATH]      Play media from a local file or folder (offline)
-T, --trending         Browse what's popular right now
-L, --lucky-tomato     Pluck a random (playable) show off the vine
-d, --download         Download the video instead of playing it
-D, --delete           Delete history
-H, --history          View the watch history
--stats                Show your watch stats (series, episodes, time, champ)
--sources              Probe which sources are working right now
-q, --quality          Specify the video quality
-v, --vlc              Use VLC to play the video
-V, --version          Show the version
-h, --help             Show help
-e, --episode          Specify episode number
-a, --audio            Choose the audio track (sub or dub). Defaults to subtitled
--dub                  Play the English dubbed version
-n, --next             Marathon mode: auto-play the next episode to the end
--preview              Peek at the first TOMATOPLAY_PREVIEW_SECS (default 60s);
                       also offered interactively after picking an episode
--cache-info           Show cache size and entries
--clear-cache          Wipe the cache
--no-cache             Disable the cache for this run
--rofi                 Use rofi for menu
--dmenu                Use dmenu for menu
-U, --update           Update the script
```

If an anime has an English dub, you'll be asked to pick the audio track
when you select an episode. You can skip the prompt with `-a sub` or `-a dub`
(or set `TOMATOPLAY_MODE`). Use the `change_audio` entry in the playback menu
to switch audio for the current episode.

## Configuration

Defaults can live in a config file at `~/.config/tomato-play/tomato-playrc`
(override the path with `TOMATOPLAY_CONFIG`). Keys are `mode`, `quality`,
`player`, `menu`, `source`, `download_dir`, `log`, and `cache_ttl`. A commented
starter is created on first run. Precedence is CLI flags > environment >
config file.

Environment variables:

- `TOMATOPLAY_DEFAULT_SOURCE` - Default source (default: all)
- `TOMATOPLAY_PLAYER` - Default player
- `TOMATOPLAY_QUALITY` - Default quality
- `TOMATOPLAY_DOWNLOAD_DIR` - Download directory
- `TOMATOPLAY_MENU` - Menu program (fzf, rofi, dmenu)
- `TOMATOPLAY_MODE` - Default audio track (sub, dub)
- `TOMATOPLAY_PREVIEW_SECS` - Preview length in seconds for `--preview` (default: 60)
- `TOMATOPLAY_RESUME_BACK` - Seconds rewound when resuming a partial episode (default: 10)
- `TOMATOPLAY_CONFIG` - Config file path (default: `~/.config/tomato-play/tomato-playrc`)
- `TOMATOPLAY_CACHE_DIR` - Override the response-cache directory (default: `~/.cache/tomato-play`)
- `TOMATOPLAY_CACHE_TTL` - Days before the whole cache is wiped (default: 7)
- `TOMATOPLAY_PROXY` - Proxy for all provider requests (e.g. `socks5h://127.0.0.1:1080`); unblock bilibili with this

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

GPL-3.0 License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [ani-cli](https://github.com/pystardust/ani-cli) - Original anime CLI tool
- All the streaming sources that make this possible
