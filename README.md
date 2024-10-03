# uosc_history_menu
在MPV播放器中添加基于uosc的播放记录列表。
# 主要功能
## 1. 播放记录列表
### 播放记录过滤
更改配置文件中的`menu_filter`可以设置默认的过滤方式。
打开列表时可以按键切换过滤方式：方向键←/→。
 - 全部：显示全部播放记录（`menu_filter=all`）
 ![图片](https://github.com/Koopex/uosc_history_menu/blob/main/preview/%E5%85%A8%E9%83%A8.png?raw=true)
 - 去重：每个视频只显示一条最新的记录（`menu_filter=dry`）
 ![图片](https://github.com/Koopex/uosc_history_menu/blob/main/preview/%E5%8E%BB%E9%87%8D.png?raw=true)
 - 目录：列出播放过的目录（`menu_filter=dic`）
![图片](https://github.com/Koopex/uosc_history_menu/blob/main/preview/%E7%9B%AE%E5%BD%95.png?raw=true)
### 删除播放记录
打开列表，移动到选择的记录，点击删除图标或者按Delete键删除，不同的过滤方式中，删除的记录不同：
 - 过滤方式为“全部”时，删除选定的记录。
 - 过滤方式为“去重”时，删除该视频所有的记录。
 - 过滤方式为“目录”时，删除该目录所有的记录。
## 2. 恢复播放
### 三种设置
 - 恢复上次关闭的文件`start_action=resume`
 - 打开播放记录`start_action=menu`
 - 什么也不做`start_action=no`
## 3. 提示本目录上次播放的视频
打开视频时，本目录上次播放的视频会被标记。`last_vedio=yes`时，打开视频会弹出列表并标记。
![图片](https://github.com/Koopex/uosc_history_menu/blob/main/preview/%E5%90%8C%E7%9B%AE%E5%BD%95%E6%81%A2%E5%A4%8D.gif?raw=true)
# 使用方法
## 1. 添加uosc按钮
 在uosc的script-opts中，在`controls=`后面找到合适的位置添加`button:history`，比如添加在全屏按钮前：
 ```
 controls=menu,ST-stats_tog,gap,play_pause,gap,subtitles,audio,<has_chapter>chapters,<has_many_edition>editions,<has_many_video>video,<stream>stream-quality,gap,space,speed,space,shuffle,loop-playlist,loop-file,gap,prev,items,next,gap,button:history,fullscreen
```
## 2. 绑定快捷键
在`input.conf`中添加`script-message toggle_history_menu`和`script-message clear_history`，可以绑定快捷键，如
```
 r       script-message toggle_history_menu
 Ctrl+r  script-message clear_history
```
按`r`键开关列表，按`Ctrl+r`清除播放记录
## 3. 其他配置选项
### 3.1 视频标题后面显示的信息
更改`hint`可以改变标题后的信息：
|hint=|显示的信息|示例|
|--|--|--|
|`date`|时间日期|`10-03 07:15`|
|`position`|播放进度|`15:45`|
|`duration`|视频时长|`24:16`|
|`percent`|播放进度%|`86%`|
|`percent+duration`|播放进度% + 视频时长|`86% 24:16`|
|`position+duration`|播放进度 + 视频时长|`15:45 / 24:16`|
 - 当过滤方式为“目录”时，显示的信息自动变成当前文件在目录中的次序，如：`3/12`
### 3.2 菜单中显示正在播放的视频
当`show_playing=yes`时，列表的第一项显示当前播放的视频。
 - 过滤方式为“全部”或“去重”：
 ![图片](https://github.com/Koopex/uosc_history_menu/blob/main/preview/%E6%98%BE%E7%A4%BA%E5%BD%93%E5%89%8D%E8%A7%86%E9%A2%91all.png?raw=true)
 - 过滤方式为“目录”：
 ![图片](https://github.com/Koopex/uosc_history_menu/blob/main/preview/%E6%98%BE%E7%A4%BA%E5%BD%93%E5%89%8D%E8%A7%86%E9%A2%91dic.png?raw=true)
### 3.3 简化标题
 - 设置`simplified_media_title=yes`可以改变视频的`media-title`，uosc顶部的标题会跟着改变。
   开启以后播放视频得到的记录才会简化，之前记录的不会。
  
 - 如果简化的效果不理想可以添加屏蔽词：`blocked_words=`
 屏蔽词较长的写在前面，短的在后，用`,`连接。屏蔽词中的`-`和`.`前面要加上`%`，如`WEB-DL`要写成`WEB%-DL`

