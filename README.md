[中文](https://github.com/Koopex/uosc_history_menu/blob/main/README-zh.md)|English

# uosc\_history\_menu

Adds uosc-based playback history to MPV player.

## Features

### 1. Playback History

#### History Filtering

Modify `menu_filter` in `uosc_history_menu.conf` to set the default filtering mode.
Press **←/→** arrow keys to temporarily switch filtering modes while the list is open.

* ​`menu_filter=all`​: Shows all playback history.
  ![Preview](https://raw.githubusercontent.com/Koopex/uosc_history_menu/refs/heads/main/preview/all-en.png)
* ​`menu_filter=deduplicated`: Shows only the latest record per video.
  ![Preview](https://raw.githubusercontent.com/Koopex/uosc_history_menu/refs/heads/main/preview/deduplicated-en.png)
* ​`menu_filter=folders`​: Lists played folders, useful for watching multiple series (if the folder is named like "Season 2," the parent folder will be displayed instead).
  ![Preview](https://raw.githubusercontent.com/Koopex/uosc_history_menu/refs/heads/main/preview/folders-en.png)

#### Deleting History

Open the list, navigate to an entry, and click the delete icon or press ​**Delete**​. The deletion behavior varies by filtering mode:

* ​`menu_filter=all`​: Deletes the selected entry.
* ​`menu_filter=deduplicated`​: Deletes all records of the selected video.
* ​`menu_filter=folders`​: Deletes all records in the selected folder.

You can also clear the entire history via a hotkey (see: ​[Keybindings](https://github.com/Koopex/uosc_history_menu/edit/main/README.md#3-keybindings)​).
![Preview](https://raw.githubusercontent.com/Koopex/uosc_history_menu/refs/heads/main/preview/clear-en.png)

#### Streaming History

* Disabled by default; enable with `log_url=yes`.
* For Bilibili, recommended to use with [Play-With-MPV](https://github.com/LuckyPuppy514/external-player) and ​[uosc\_danmaku](https://github.com/Tony15246/uosc_danmaku).

### 2. Resume Playback

#### Using Hotkeys

Press `Space` (or another key) to resume the last played file.

#### Actions on MPV Startup

* Resume last closed file: `start_action=resume`
* Open history menu: `start_action=menu`
* Do nothing: `start_action=no`

### 3. Highlight Last Played Video in Directory

When opening a video via file explorer, the last played video in the same directory will be marked. If `last_video=yes` and the opened video is not the last played one, a list will pop up with the last played entry highlighted.

## Usage

### 1. Install [uosc]([uosc](https://github.com/tomasklaen/uosc))

### 2. Adding uosc Button

In uosc's `script-opts`, find the `controls=` section and add `button:history` in a suitable position:

```
controls='menu,button:history,gap,subtitles,<has_many_audio>audio,<has_many_video>video,<has_many_edition>editions,<stream>stream-quality,gap,space,speed,space,shuffle,loop-playlist,loop-file,gap,prev,items,next,gap,fullscreen'
```

### 3. Keybindings

Add these lines to `input.conf` to set hotkeys:

```
SPACE   script-binding uosc_history_menu/play_last_video
r       script-binding uosc_history_menu/toggle_history_menu
Ctrl+r  script-binding uosc_history_menu/clear_history
```

* ​`Space`: Resumes last playback (disable default Space binding; set `space=yes` in `script-opts/uosc_history_menu.conf`).
* ​`r`​: Toggles history menu.
* `Ctrl+r`​: Clears playback history.

### 3. Additional Configurations

#### Info Displayed After Video Title

Modify `hint` to change the post-title info:

| `hint=`             | Displays                     | Example             |
| ------------------------- | ------------------------------ | --------------------- |
| `percent`           | Playback progress                  | `86%`           |
| `percent+duration`  | Playback progress and duration        | `86% 24:16`     |
| `position+duration` | Time played and duration | `15:45 / 24:16` |

* Only applies to **Deduplicated** mode.
* **Folders** mode shows file order (e.g., `3/12`).
* **All** mode shows playback datetime (e.g., `2025-05-17 11:02`).

#### Simplified Titles

* Set `simplified_media_title=yes` to modify `media-title`, which also updates uosc's top bar title.
  (Only affects new records; existing ones remain unchanged.)
* If simplification is unsatisfactory, add blocked words: `blocked_words=`.
  Longer words should come first, separated by commas. Escape `-` and `.` with `%` (e.g., `WEB%-DL`).

## Credits

Special thanks to these projects for inspiration:

* [MPV](https://github.com/mpv-player/mpv)
* [MPV\_lazy](https://github.com/hooke007/MPV_lazy)
* [uosc](https://github.com/tomasklaen/uosc)
* [uosc\_danmaku](https://github.com/Tony15246/uosc_danmaku)
* [SimpleHistory](https://github.com/dyphire/Eisa01_mpv-scripts/blob/dev/scripts/simplehistory.lua)
* [Play-With-MPV](https://github.com/LuckyPuppy514/external-player)

