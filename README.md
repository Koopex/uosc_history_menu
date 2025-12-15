[![Static Badge](https://img.shields.io/badge/README-简体中文-red)](./README-zh.md)

# uosc_history_menu

Adds a playback history and bookmark management menu integrated with [uosc](https://github.com/tomasklaen/uosc) for mpv.

# Features

## 1. Playback History

### History Filtering

When the list is open, you can quickly switch **filtering modes** using the `Left/Right Arrow Keys`.

| Filtering Mode | Description | Hint Information | Effect of Delete Operation |
| --- | --- | --- | --- |
| All Records | A video may have multiple entries at different progress points. | Playback Date & Time | Deletes only the **single selected record** |
| Recent Media | Shows only the **latest record for each video**. | Playback Duration / Total Duration | Deletes **all history records for that video** |
| Recent Folders | Shows **one latest record per folder**. | Watched Videos / Total Videos in Folder | Deletes records for **all videos within that folder** |

## 2. Resume Playback

- **One-Click Resume**: When mpv is in an **idle state** (no file loaded), press the **Play/Pause key** to directly resume the last watched video.

- **Auto-Resume on Startup**: After setting `start_action=resume` in the configuration file, mpv will automatically resume the last video upon startup.

- **Resume in Same Folder**: After setting `resume_in_folder=yes` in the configuration file, when you open a video in a folder, if there are other video records in the same folder, the script will pop up a menu asking if you want to jump to resume playback.

## 3. Bookmark Management

- **Add bookmark**: You can add any **history record** or **currently playing video** as a bookmark and manage them.
  - **Quick bookmark mode**: Add bookmarks directly to the default bookmark group without group selection. Toggle with the hotkey `script-binding uosc_history/toggle_quick_mark`.
- **Other operations**:
  || Group | Bookmark Item |
  | --- | --- | --- |
  | Delete | Can only use shortcut `Del` | Shortcut or button |
  | Sort | Move Up: `Ctrl+Up/PgUp/Home`<br>Move Down: `Ctrl+Down/PgDn/End` | Same as left |
  | Rename | Can only use shortcut `Left Arrow` | `Right Arrow` or button |
  | Change Group | - | Button |

# Usage

## 1. Install [uosc](https://github.com/tomasklaen/uosc)

## 2. Install This Script

Place `uosc_history.lua` in your `scripts` folder.

Edit `uosc_history.conf` and place it in your `script-opts` folder.

## 3. Add uosc Button

Edit `uosc.conf`, find a suitable position after `controls=` and add `button:history`:

```
controls='menu,button:history,gap...',
```

Available buttons:

 - `button:history`: Playback History
 - `button:bookmarks`: Bookmarks  
 - `button:add_bookmarks`: Add Bookmark

<a id="Keybindings"></a>

## 4. Bind Hotkeys

You can add the following hotkeys to your `input.conf`:

```
r			script-binding uosc_history/history				#! Playback History
Ctrl+r		script-binding uosc_history/enable_history		#! Disable History
Ctrl+Alt+r	script-binding uosc_history/clear_history		#! Clear History

d			script-binding uosc_history/bookmarks			#! Bookmarks
Ctrl+d		script-binding uosc_history/add_bookmarks		#! Add Bookmarks
Alt+d		script-binding uosc_history/toggle_quick_mark	#! Switch Quick Bookmark Mode
Ctrl+Alt+d	script-binding uosc_history/clear_bookmarks		#! Clear Bookmarks	
```

---  

## Credits & References:

- [uosc](https://github.com/tomasklaen/uosc)
- [SimpleHistory](https://github.com/dyphire/Eisa01_mpv-scripts/blob/dev/scripts/simplehistory.lua)
- [history-bookmark.lua](https://github.com/yuukidach/mpv-scripts/blob/master/README.zh-CN.md#history-bookmarklua)
- [uosc_danmaku](https://github.com/Tony15246/uosc_danmaku)
- [mpv\_PlayKit](https://github.com/hooke007/mpv_PlayKit)
