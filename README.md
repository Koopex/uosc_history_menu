[中文](https://github.com/Koopex/uosc_history_menu/blob/main/README-zh.md)|English

# uosc_history_menu

Adds [uosc](https://github.com/tomasklaen/uosc)-based playback history to mpv player.

# Features

## 1. Playback History

### History Filtering

Press ←/→ arrow keys to switch filtering modes while the menu is open.

| Filtering Modes  | Explanation                                              | Hint                               | Delete Record                  |
| ------------------ | ---------------------------------------------------------- | ------------------------------------ | -------------------------------- |
| All Records      | Multiple entries per video, each at different timestamps | Playback Date & Time               | Current entry                  |
| Recent Media | One entry per video                                      | Playback Duration / Total Duration | All records for that video     |
| Recent Folders   | One entry per folder                                     | Watched Videos / Total Videos      | All records within that folder |

## 2. Resume Playback

### One-Click Resume

Simply press "Play/Pause" when mpv is idle.

### Resume Immediately on Startup

* Requires changing the setting: `start_action=resume`

## 3. Bookmarks

Add bookmarks from playback history or currently playing file.

Supports renaming, sorting, and deleting bookmarks.

* Sort only via hotkeys: Move up `Ctrl+Up/PgUp/Home`, Move down `Ctrl+Down/PgDn/End`

## 4. Prompt for Last Played Video in the Same Directory

* Requires changing the setting: `resume_in_folder=yes`

For example, if you directly open Episode 2 at `~~/TV-show/S01E02.mkv` while a playback record exists for Episode 17 at `~~/TV-show/S01E17.mkv`, a menu will pop up prompting you to resume playback from Episode 17.

# Usage

## 1. Install [uosc](https://github.com/tomasklaen/uosc)

## 2. Install this script

Place `uosc_history.lua` in your mpv `scripts` folder

Edit `uosc_history.conf` and place it in your mpv `script-opts` folder

## 3. Add the uosc Button

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
e               script-binding uosc_history/bookmarks          #! Bookmarks
Ctrl+e          script-binding uosc_history/add_bookmarks      #! Add Bookmark
Ctrl+Alt+e      script-binding uosc_history/clear_bookmarks    #! Clear Bookmarks                   
r               script-binding uosc_history/history            #! Playback History                        
Ctrl+r          script-binding uosc_history/enable_history     #! Enable/Disable History
Ctrl+Alt+r      script-binding uosc_history/clear_history      #! Clear History
```


# Credits

Thanks to the following projects for reference!

- [mpv](https://github.com/mpv-player/mpv)
- [mpv\_PlayKit](https://github.com/hooke007/mpv_PlayKit)
- [uosc](https://github.com/tomasklaen/uosc)
- [uosc_danmaku](https://github.com/Tony15246/uosc_danmaku)
- [SimpleHistory](https://github.com/dyphire/Eisa01_mpv-scripts/blob/dev/scripts/simplehistory.lua)
- [外部播放器(Play-With-MPV)](https://github.com/LuckyPuppy514/external-player)
