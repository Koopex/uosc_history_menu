[![Static Badge](https://img.shields.io/badge/README-简体中文-red)](./README-zh.md)

# uosc_history_menu

Adds a playback history and bookmark management menu integrated with [uosc](https://github.com/tomasklaen/uosc) for mpv.

# Features

## 1. Playback History

### History Filtering

Use `Left/Right Arrow Keys` to switch filtering modes when the menu is open.

| Filter | Description | Hint | Delete Scope |
| --- | --- | --- | --- |
| All Records | Multiple entries per video at different progress points | Playback date & time | Single selected record |
| Recent Media | Latest record per video | Played / Total duration | All records for that video |
| By Folder | One latest record per folder | Watched / Total in folder | All videos in that folder |

## 2. Resume Playback

- **One-Click Resume**: When mpv is idle, press **Play/Pause** to resume the last watched video.
- **Auto-Resume on Startup**: Set `startup_action=resume` to auto-resume the last video on launch.
- **Resume in Same Folder**: Set `resume_in_folder=yes` to be prompted when other videos in the same folder have playback history.

## 3. Bookmarks

- **Add Bookmark**: Bookmark any history record or currently playing video.
  - **Quick Bookmark**: Add directly to the default group. Toggle with `script-binding uosc_history/toggle_quick_mark`.
- **Operations**:
  | | Group | Item |
  | --- | --- | --- |
  | Delete | Shortcut `Del` only | Shortcut or button |
  | Sort | Up: `Ctrl+Up/PgUp/Home`<br>Down: `Ctrl+Down/PgDn/End` | Same |
  | Rename | Shortcut `Left Arrow` only | `Right Arrow` or button |
  | Move | — | Button |

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

<a id="Keybindings"></a>

## 4. Bind Hotkeys

Add to your `input.conf`:

```
r               script-binding uosc_history/history             #! Playback History
Ctrl+r          script-binding uosc_history/enable_history      #! Toggle History
Ctrl+Alt+r      script-binding uosc_history/clear_history       #! Clear History

d               script-binding uosc_history/bookmarks           #! Bookmarks
Ctrl+d          script-binding uosc_history/add_bookmarks       #! Add Bookmark
Alt+d           script-binding uosc_history/toggle_quick_mark   #! Quick Bookmark
Ctrl+Alt+d      script-binding uosc_history/clear_bookmarks     #! Clear Bookmarks
```

---

## Credits

- [uosc](https://github.com/tomasklaen/uosc)
- [SimpleHistory](https://github.com/dyphire/Eisa01_mpv-scripts/blob/dev/scripts/simplehistory.lua)
- [history-bookmark.lua](https://github.com/yuukidach/mpv-scripts/blob/master/README.zh-CN.md#history-bookmarklua)
- [uosc_danmaku](https://github.com/Tony15246/uosc_danmaku)
- [mpv_PlayKit](https://github.com/hooke007/mpv_PlayKit)
