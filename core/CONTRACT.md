# Core module contract

The files in `core/` are sourced by `tomatoplay` into one POSIX shell process.
They are not standalone commands: their functions read and sometimes update the
CLI state described below. The entry point owns initialization, option parsing,
provider and player setup, and the top-level control flow. Core functions own
the behavior named by their module.

## Module responsibilities and dependencies

| Module | Responsibility | Main dependencies |
| --- | --- | --- |
| `search.sh` | Relax queries, rank results, and annotate torrent rows | `provider_search`, `provider_peer_count`, `render_torrent_line` |
| `history.sh` | Read and update watch history; restore continuation state | History read/write helpers accept explicit row/path arguments; continuation depends on provider APIs but does not mutate playback flow state |
| `menu.sh` | Adapt terminal menus and return a home-menu action | `menu PROGRAM PROMPT MULTI_SELECT FLAGS`; sets `_home_action` for `home_menu` |
| `selection.sh` | Map selected rows and episode numbers to provider keys | `menu`, `die`, provider APIs; selection inputs/settings are explicit while resolved playback values are returned through flow state |
| `result_filter.sh` | Keep results that have a usable episode/playback path | `filter_entries SOURCE` reads result rows from stdin; provider APIs and `_probe_playable` |
| `room.sh` | Create mpv room scripts and prepare guest media paths | `room_dir`, `hist_dir`, `room_role`; sets `_room_flag` and `local_path` |
| `stream_resolution.sh` | Resolve stream choices and perform source-aware probes | provider stream APIs, `source`, `anime_id`, `ep_no`, `mode`, `quality`; updates `links` and `video_link` |
| `torrent_playback.sh` | Resolve torrent files and hand them to a player or cast target | `video_link`, `links`, player/config state, `room_bootstrap`, `_urlencode` |
| `player.sh` | Dispatch configured player commands and browser fallbacks | prepared media, player, source, and option state; sets `mpv_exitcode` for foreground mpv |
| `playback.sh` | Orchestrate episode lifecycle, resume state, and history | stream, provider, room, torrent, and player helpers; active CLI state |

## Shared state rules

- `tomatoplay` initializes configuration and flow state before the main search
  and playback functions run. New required state must be initialized there with
  a default, even when an environment override is supported.
- Provider calls go through the public `provider_*` functions documented in
  [`../providers/CONTRACT.md`](../providers/CONTRACT.md). Core code should not
  call provider implementation functions directly.
- The principal playback state is `source`, `anime_id`, `anime_title`, `ep_no`,
  `episode_maps`, `mode`, `quality`, `links`, and `video_link`. Selection and
  history helpers may update these values as part of their documented behavior.
- Configuration and service state such as `player_function`, `player_extra_flags`,
  `download_dir`, `resume_back`, `agent`, `curl_exe`, `cipher_flag`, `_px_flag`,
  `histfile`, `resume_dir`, `hist_dir`, and menu settings is initialized by the
  entry point and read by modules.
- Shell functions share global variables; POSIX shell has no portable lexical
  scope. Use distinctive module/function prefixes for temporary variables,
  avoid reusing another module's scratch names, and do not assume a helper is
  reentrant. Values intentionally returned through globals must be named in the
  function's comments or this contract.
- Functions that return machine-readable rows write them to stdout and send
  diagnostics to stderr. Helpers that mutate shared flow state should document
  which variables they set. Return status reports success/failure; do not call
  `exit` from reusable core helpers unless the function is explicitly a
  top-level CLI action.
- Selection helper interfaces are explicit: `nth PROMPT MULTI_SELECT MENU_FLAGS MENU_PROGRAM`,
  `select_episode_numbers EPISODE_MAPS MULTI_SELECT MENU_FLAGS MENU_PROGRAM`, and
  `episode_key_for_number EPISODE_MAPS DISPLAY_NUMBER`. The state transitions
  use `resolve_title RESULTS INDEX SOURCE MENU_FLAGS MENU_PROGRAM` and
  `resolve_episodes SOURCE ANIME_ID REQUESTED_EPISODE MULTI_SELECT MENU_FLAGS MENU_PROGRAM`.
  Pass menu configuration from the entry point instead of letting selection
  helpers read it globally.
- History display interfaces are explicit: `history_view HISTORY_FILE` and
  `garden_stats HISTORY_FILE`. The entry point supplies the configured history
  path.
- History writes use `update_history HISTORY_FILE SOURCE ANIME_ID EPISODE TITLE`
  so playback state is passed at the call site.
- Continuation rows use `process_hist_entry RESUME_DIR EPISODE SAVED_ID TITLE`
  and emit a row without changing active playback state.

## Load order

The entry point loads provider adapters and dispatch before core modules. Core
modules are loaded in this order: search, history, menu, selection, result
filtering, room setup, stream resolution, torrent playback, player adapters,
and playback orchestration. Keep dependency order explicit in `tomatoplay` when
adding a module, and add an offline test for any new public helper or state
transition.
