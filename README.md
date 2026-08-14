[![Static Badge](https://img.shields.io/badge/README-简体中文-red)](./README-zh.md)

# uosc_history_menu

Adds a playback history and bookmark management menu integrated with [uosc](https://github.com/tomasklaen/uosc) for mpv.

# Features

## 1. Playback History

### History Filtering

Use `Left/Right Arrow Keys` to switch filtering modes when the menu is open (All Records <-> Recent Media <-> By Source).

| Filter | Description | Hint | Delete Scope |
| --- | --- | --- | --- |
| All Records | Multiple entries per video at different progress points | Playback date & time | Single selected record |
| Recent Media | Latest record per video | Played / Total duration | All records for that video |
| By Source | Records grouped by folder (local files) or domain/IP (URLs), shown in submenus | Played / Total duration | All records in that folder/domain |

> **By Source**: nested submenus by folder/domain by default. With `source_view_flat=yes`, local files use flat grouping (only the newest record per folder, hint shows in-folder position); URLs are still grouped by domain/IP.

### Icons

Items are prefixed with a type icon: `🔗` URL, `🎬` local file, `📁` folder.

## 2. Resume Playback

- **One-Click Resume**: When mpv is idle, press **Play/Pause** to resume the last watched video.
- **Auto-Resume on Startup**: Set `startup_action=resume` to auto-resume the last video on launch.
- **Resume in Same Folder**: Set `resume_in_folder=yes` to be prompted when other videos in the same folder have playback history. If the latest record's progress exceeds `restart_threshold`, the prompt offers the next file in the folder, played from the start.   
> **Restart Threshold**: When opening a history entry, if the played progress exceeds `restart_threshold` (default 90%), playback starts from the beginning. `0` always restarts, `100` always resumes progress.

## 3. Bookmarks

- **Grouping**: Groups can contain sub-groups of any depth; folders and items can be mixed.
- **Add Bookmark**: You can bookmark a history record, the currently playing video, or the current playlist, and also import bookmarks from the clipboard.
  - **Quick Bookmark Mode**: Toggle the mode with a shortcut. In this mode, items are added directly to the Quick Bookmark group without choosing a location.
- **Item Operations**:
  | Operation | Shortcut | Description |
  | --- | --- | --- |
  | Delete | `Del` |  |
  | Rename | `F2` |  |
  | New Group | `Ctrl+n` | Create a new group in the current level |
  | Reorder | `Ctrl+Home/End/PgUp/PgDw/↑/↓` |  |
  | Move | *(action button)* | Move the item to a chosen location |
  | Copy / Cut | `Ctrl+c` / `Ctrl+x` | Copies item info to the clipboard (JSON format) |
  | Paste / Import | `Ctrl+v` | Open the bookmarks menu, then import below the currently selected item:<br>1. Paste a path or URL, then enter a name when prompted<br>2. Copy an item from history or bookmarks and paste it at the desired location<br>3. Paste a hand-written JSON array/table. Items require `title` and `path`; groups require `title` and `items` (array) |

# Configuration

Edit `script-opts/uosc_history.conf`:

| Option | Default | Description |
| --- | --- | --- |
| `language` | `zh` | UI language: `zh` or `en` |
| `startup_action` | `none` | Action on startup: `resume` / `menu` / `none` |
| `resume_in_folder` | `no` | Prompt to resume when other videos in the same folder have history |
| `restart_threshold` | `90` | Play from the beginning when progress exceeds this percentage |
| `use_filename` | `no` | Use filename instead of media title |
| `search_sorting` | `no` | Sort search results by play time |
| `source_view_flat` | `no` | "By Source" view: `yes` = flat grouping (newest record per folder), `no` = nested submenus |
| `max_entries` | `0` | Max history entries kept (`0` = unlimited) |
| `bookmark_new_group_button` | `no` | Show a "New Group" button at the top of every bookmarks level |
| `history_actions` | `mark,delete` | Action buttons for history entries (comma-separated; empty = none, shortcuts still work) |
| `bookmark_actions` | `rename,move,delete` | Action buttons for bookmark entries (comma-separated; empty = none, shortcuts still work) |
| `data_path` | `~~/uosc_history.json` | History data file |
| `bookmark_path` | *(empty)* | Separate bookmark file; empty = same file as `data_path` |

# Usage

## 1. Install [uosc](https://github.com/tomasklaen/uosc)

## 2. Install This Script

Place the `uosc_history` folder into your `scripts` directory.

Place `uosc_history.conf` into your `script-opts` directory.

## 3. Add uosc Buttons

In `uosc.conf`, find `controls=` and add buttons:

```
controls=menu,button:history,gap...,
```

Available buttons:
- `button:history`: Playback History
- `button:bookmarks`: Bookmarks
- `button:add_bookmarks`: Add Bookmark
- `button:add_playlist`: Bookmark Playlist

<a id="Keybindings"></a>

## 4. Bind Hotkeys

Add to your `input.conf`:

```
r               script-binding uosc_history/history             #! Playback History
Ctrl+r          script-binding uosc_history/enable_history      #! Toggle History
Ctrl+Alt+r      script-binding uosc_history/clear_history       #! Clear History

d               script-binding uosc_history/bookmarks           #! Bookmarks
Ctrl+d          script-binding uosc_history/add_bookmarks       #! Add Bookmark
Ctrl+D          script-binding uosc_history/add_playlist        #! Bookmark Playlist
Alt+d           script-binding uosc_history/toggle_quick_mark   #! Toggle Quick Bookmark
Ctrl+Alt+d      script-binding uosc_history/clear_bookmarks     #! Clear Bookmarks
```

---

## Credits

- [uosc](https://github.com/tomasklaen/uosc)
- [SimpleHistory](https://github.com/dyphire/Eisa01_mpv-scripts/blob/dev/scripts/simplehistory.lua)
- [history-bookmark.lua](https://github.com/yuukidach/mpv-scripts/blob/master/README.zh-CN.md#history-bookmarklua)
- [uosc_danmaku](https://github.com/Tony15246/uosc_danmaku)
- [mpv_PlayKit](https://github.com/hooke007/mpv_PlayKit)
