中文|[English](https://github.com/Koopex/uosc_history_menu/blob/main/README.md)

# uosc_history_menu

在MPV播放器中添加基于uosc的播放记录。

# 主要功能

## 1. 播放记录

### 播放记录过滤

更改`uosc_history_menu.conf`的`menu_filter`可以设置默认的过滤方式。
打开列表时可以按方向键←/→临切换过滤方式。

- 全部：显示全部播放记录（`menu_filter=all`）

![Preview](https://raw.githubusercontent.com/Koopex/uosc_history_menu/refs/heads/main/preview/all-zh.png)

- 去重：每个视频只显示一条最新的记录（`menu_filter=deduplicated`）

![Preview](https://raw.githubusercontent.com/Koopex/uosc_history_menu/refs/heads/main/preview/deduplicated-zh.png)

- 文件夹：列出播放过的文件夹（`menu_filter=folders`）,适合同时看多个剧 (如果文件夹是"Season 2"这种形式,则显示更外层的文件夹)

![Preview](https://raw.githubusercontent.com/Koopex/uosc_history_menu/refs/heads/main/preview/folders-zh.png)

### 删除播放记录

打开列表，移动到选择的记录，点击删除图标或者按`Delete`键删除，不同的过滤方式中，删除的记录不同：

- 过滤方式为“全部”时（`menu_filter=all`），删除选定的记录。
- 过滤方式为“去重”时（`menu_filter=deduplicated`），删除该视频所有的记录。
- 过滤方式为“文件夹”时（`menu_filter=folders`），删除该目录所有的记录。
  
  也可以通过快捷键清空播放记录，见[绑定快捷键](https://github.com/Koopex/uosc_history_menu/edit/main/README.md#3-keybindings)
![Preview](https://raw.githubusercontent.com/Koopex/uosc_history_menu/refs/heads/main/preview/clear-zh.png)

### 流媒体播放记录

- 默认关闭, `log_url=yes`开启
- 看B站建议配合[外部播放器(Play-With-MPV)](https://github.com/LuckyPuppy514/external-player)和[uosc_danmaku](https://github.com/Tony15246/uosc_danmaku)使用

## 2. 恢复播放

### 使用快捷键

按下`空格`(或者其他快捷键), 恢复上次播放的文件

### 打开mpv后的动作

- 恢复上次关闭的文件`start_action=resume`
- 打开播放记录`start_action=menu`
- 什么也不做`start_action=no`

## 3. 提示本目录上次播放的视频

通过资源管理器打开视频时，本目录上次播放的视频会被标记。`last_vedio=yes`时，打开的不是上次播放的视频会弹出列表并标记。
![图片](https://github.com/Koopex/uosc_history_menu/blob/main/preview/%E5%90%8C%E7%9B%AE%E5%BD%95%E6%81%A2%E5%A4%8D.gif?raw=true)

# 使用方法

## 1. 安装[uosc](https://github.com/tomasklaen/uosc)

## 2. 添加uosc按钮

在uosc的script-opts中，在`controls=`后面找到合适的位置添加`button:history`：

```
controls='menu,button:history,gap,subtitles,<has_many_audio>audio,<has_many_video>video,<has_many_edition>editions,<stream>stream-quality,gap,space,speed,space,shuffle,loop-playlist,loop-file,gap,prev,items,next,gap,fullscreen',
```

## 3. 绑定快捷键

在`input.conf`中添加以下三行，可以绑定快捷键:

```
SPACE   script-binding uosc_history_menu/play_last_video
 r       script-binding uosc_history_menu/toggle_history_menu
 Ctrl+r  script-binding uosc_history_menu/clear_history
```

按`空格`恢复上次播放,为避免冲突还要把原来的`空格`取消绑定,在`script-opts/uosc_history_menu.conf`中设置`space=yes`(不绑定`空格`就设为`space=no`)

按`r`键开关列表

按`Ctrl+r`清除播放记录

## 4. 其他配置选项

### 视频标题后面显示的信息

更改`hint`可以改变标题后的信息：

|hint=|显示的信息|示例|
|--|--|--|
|`percent`|播放进度%|`86%`|
|`percent+duration`|播放进度% + 视频时长|`86% 24:16`|
|`position+duration`|播放进度 + 视频时长|`15:45 / 24:16`|

- 只有过滤方式为"去重"时才生效，其他两种过滤方式显示固定的内容
- 当过滤方式为“文件夹”时，显示当前文件在目录中的次序，如：`3/12`
- 当过滤方式为“全部”时，显示播放日期时间，如：`2025-05-17 11:02`

### 简化标题

- 设置`simplified_media_title=yes`可以改变视频的`media-title`，uosc顶部的标题会跟着改变。
  开启以后新得到的记录才会简化，之前记录的不会。
- 如果简化的效果不理想可以添加屏蔽词：`blocked_words=`
  屏蔽词较长的写在前面，短的在后，用`,`连接。屏蔽词中的`-`和`.`前面要加上`%`，如`WEB-DL`要写成`WEB%-DL`

# 感谢!

特别感谢以下项目提供参考!

- [mpv](https://github.com/mpv-player/mpv)
- [mpv_lazy](https://github.com/hooke007/MPV_lazy)
- [uosc](https://github.com/tomasklaen/uosc)
- [uosc_danmaku](https://github.com/Tony15246/uosc_danmaku)
- [SimpleHistory](https://github.com/dyphire/Eisa01_mpv-scripts/blob/dev/scripts/simplehistory.lua)
- [外部播放器(Play-With-MPV)](https://github.com/LuckyPuppy514/external-player)



