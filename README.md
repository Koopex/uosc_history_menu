[![Static Badge](https://img.shields.io/badge/README-简体中文-red)](./README-zh.md)

# uosc_history_menu

A playback history and bookmark manager for mpv, deeply integrated with [uosc](https://github.com/tomasklaen/uosc).

- Track playback history with three filter views
- Resume playback: one-key resume, startup resume, and same-folder resume
- Manage bookmarks in nested groups of any depth, with clipboard import/export
- Add history and bookmark items to the playlist, or bookmark the current playlist

---

## Playback History

Every play session is recorded with its path, title, position, duration and time. Open the history menu (default `r`) to browse it.

### Filter Views

Switch between views with `←` / `→` while the history menu is open.

| View | Description | Hint | Delete scope |
| --- | --- | --- | --- |
| **All Records** | Every record; the same video can appear multiple times at different positions | Playback time | The selected record only |
| **Recent Media** | The latest record per video | Played / total duration | All records of that video |
| **By Source** | Local files grouped by folder, URLs by domain/IP, shown in submenus | Played / total duration | All records in that folder / domain |

> **By Source**: groups into nested submenus by default. With `source_view_flat=yes`, local files use flat grouping (only the newest record per folder); URLs are always grouped by domain/IP.

### Search

Press `Ctrl+f` to search the current history. With `search_sorting=yes`, results are ordered by most recent playback time instead of uosc's default order.

### Icons

Entries are prefixed with a type icon: `🔗` URL, `🎬` local file, `📁` folder.

---

## Resume Playback

- **One-key resume** — When mpv is idle, press **Play/Pause** to resume the most recently played file.
- **Resume on startup** — Set `startup_action=resume` to resume the last file automatically; `startup_action=menu` opens the history menu on launch.
- **Same-folder resume** — With `resume_in_folder=yes`, opening a file prompts you to continue a different file from the same folder if one has playback history. If the newest record's progress exceeds `restart_threshold`, the prompt offers the **next file in the folder**, played from the start.
- **Restart threshold** — When opening a history entry whose progress exceeds `restart_threshold` (default `90`%), playback starts from the beginning. `0` always restarts, `100` always resumes.

---

## Bookmarks

### Groups

Groups can contain sub-groups at any depth, and folders and items can be freely mixed. Open the bookmarks menu (default `d`) to manage them.

### Adding Bookmarks

- From a history entry (`Ctrl+d` while a history item is selected)
- The currently playing video (default `Ctrl+d` when not in a menu)
- The current playlist (default `Ctrl+D`)
- Pasting a path, a URL, or a hand-written JSON structure (see below)

**Quick Bookmark mode** (`Alt+d`) adds entries directly to the *Quick Bookmark* group without asking for a location.

### Item Operations

| Operation | Shortcut | Description |
| --- | --- | --- |
| Delete | `Del` | Remove the selected item |
| Rename | `F2` | Rename the selected item (current name is pre-filled) |
| New Group | `Ctrl+n` | Create a group in the current level |
| Reorder | `Ctrl+Home/End/PgUp/PgDw/↑/↓` | Reorder items in the current level |
| Move | `Ctrl+m` | Move the item to a chosen location |
| Copy / Cut | `Ctrl+c` / `Ctrl+x` | Copy or cut the item as JSON to the clipboard |
| Paste / Import | `Ctrl+v` | Paste below the selected item |
| Add to Playlist | `Ctrl+p` | Append the item (or group) to the playlist |

### Paste & Import

1. A plain **path or URL** — you are prompted for a title, then it is added as a bookmark.
2. An item **copied from history or bookmarks** — inserted below the selected item. Pasted entries are checked for duplicates within the current level.
3. A hand-written **JSON array/table** — an item needs `title` and `path`; a group needs `title` and `items` (an array). Each valid entry is inserted in order; invalid ones are skipped.

---

## Playlist Integration

- **Add to playlist** (`Ctrl+p` / *Add to Playlist* button) appends history and bookmark entries to the playlist without interrupting playback. Appended entries keep their titles, so the playlist stays readable even for URLs and files without metadata.
- **Group playback** — With `bookmark_play_group=siblings` or `subtree`, clicking a bookmark item loads its containing group as a playlist: `siblings` includes only the same-level items, `subtree` flattens the whole nested group. The clicked item starts with its saved position, the others play from the beginning in menu order.
- **Bookmark the current playlist** (`Ctrl+D` / *Bookmark Playlist* button) saves the whole playlist into a group (or a location you choose when not in Quick Bookmark mode).

---

## Configuration

Edit `script-opts/uosc_history.conf`:

| Option | Default | Description |
| --- | --- | --- |
| `language` | `zh` | UI language: `zh` or `en` |
| `startup_action` | `none` | Action on startup: `resume` / `menu` / `none` |
| `resume_in_folder` | `no` | Prompt to continue a different file from the same folder |
| `restart_threshold` | `90` | Start from the beginning when progress exceeds this percentage |
| `use_filename` | `no` | Use the filename instead of the media title |
| `source_view_flat` | `no` | "By Source" view: `yes` = flat grouping (newest record per folder), `no` = nested submenus |
| `search_sorting` | `no` | Sort search results by playback time |
| `history_actions` | `mark,delete` | Action buttons for history entries (comma-separated, in display order; empty = no buttons, shortcuts still work) |
| `bookmark_actions` | `rename,delete,[]` | Action buttons for bookmark entries (comma-separated, in display order; empty = no buttons, shortcuts still work) |
| `bookmark_new_group_button` | `no` | Show a "New Group" button at the top of every bookmarks level |
| `bookmark_play_group` | `no` | Load the containing group as a playlist when clicking a bookmark: `no` / `siblings` / `subtree` |
| `max_entries` | `0` | Maximum history entries kept (`0` = unlimited) |
| `data_path` | `~~/uosc_history.json` | History data file |
| `bookmark_path` | *(empty)* | Separate bookmark file; empty = same file as `data_path` |

### Action Buttons

- History entries: `mark` (bookmark), `delete`, `playlist` (add to playlist), `copy`.
- Bookmark entries: `new_group`, `rename`, `move`, `copy`, `cut`, `paste`, `delete`, `playlist`.
- Group syntax `[a,b,c]` collapses the listed actions into a single **More actions** button; an empty group `[]` auto-fills the actions that are not shown as buttons.

---

## Installation

1. **Install [uosc](https://github.com/tomasklaen/uosc)**.
2. **Install the script** — put the `uosc_history` folder into your `scripts` directory, and `uosc_history.conf` into your `script-opts` directory.
3. **Add uosc buttons** — in `uosc.conf`, add buttons to `controls=`:

   ```
   controls=menu,button:history,gap...,
   ```

   Available buttons:
   - `button:history` — Playback History
   - `button:bookmarks` — Bookmarks
   - `button:add_bookmarks` — Add Bookmark
   - `button:add_playlist` — Bookmark Playlist

4. **Bind hotkeys** — add to your `input.conf`:

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

## Data Storage

History and bookmarks are stored as plain JSON files, so they are easy to back up or edit by hand:

- `data_path` — playback history (default `~~/uosc_history.json`).
- `bookmark_path` — optional separate bookmark file; when empty, bookmarks are stored in the same file as history.

---

## Credits

- [uosc](https://github.com/tomasklaen/uosc)
- [SimpleHistory](https://github.com/dyphire/Eisa01_mpv-scripts/blob/dev/scripts/simplehistory.lua)
- [history-bookmark.lua](https://github.com/yuukidach/mpv-scripts/blob/master/README.zh-CN.md#history-bookmarklua)
- [uosc_danmaku](https://github.com/Tony15246/uosc_danmaku)
- [mpv_PlayKit](https://github.com/hooke007/mpv_PlayKit)