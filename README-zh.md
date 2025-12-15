[![Static Badge](https://img.shields.io/badge/README-English-blue)](./README.md)


# uosc_history_menu  

为 mpv 增加一个与 [uosc](https://github.com/tomasklaen/uosc) 集成的播放历史与收藏管理菜单。

# 主要功能

## 1. 播放记录

### 播放记录筛选

打开列表时，可以使用`←/→方向键`快速切**换筛选方式**。

|筛选方式 |说明 | 提示信息 |删除操作的影响|
| --- | --- | --- | --- |
|全部记录| 同一视频可能有多个不同进度的条目 | 播放日期 时间 |仅删除当前选中的**单条记录**|
| 播放记录 | **每个视频**只显示最新的一条记录 | 播放时长/总时长 |删除**该视频**的全部历史记录|
| 文件夹记录 | **每个文件夹**一条最新的记录 | 已看视频数/文件夹内总视频数 |删除**该文件夹**内所有视频的记录|

## 2. 继续播放

- **一键恢复**：当 mpv 处于**空闲状态**（未加载任何文件）时，按下**播放/暂停键**即可直接恢复上一次观看的视频。


- **启动自动恢复**：在配置文件中设置 `start_action=resume` 后，启动 mpv 时将自动恢复最后一个视频。

- **同文件夹续播**：在配置文件中设置 `resume_in_folder=yes` 后，当你打开某文件夹中的一个视频时，如果同文件夹内有其他视频记录，插件会弹出菜单询问你是否跳转续播。

## 3. 收藏夹管理

- **添加收藏**: 你可以将任意**历史记录**或当前**正在播放的视频**添加为书签，并对其进行管理。
  - **快速收藏模式**: 直接添加到**默认的收藏夹**, 不需要选收藏夹, 使用快捷键 `script-binding uosc_history/toggle_quick_mark` 切换
- **其他操作**: 
  ||分组|收藏项| 
  | --- | --- | --- |
  |删除|只能使用快捷键 `Del`|快捷键或按钮|
  |排序|上移：`Ctrl+Up/PgUp/Home`<br>下移 `Ctrl+Down/PgDn/End`|同左|
  |重命名|只能使用快捷键 `←方向键`| `→方向键`或按钮|
  |改变分组|-|按钮|

# 使用方法

## 1. 安装[uosc](https://github.com/tomasklaen/uosc)

## 2. 安装本插件

将`uosc_history.lua`放入你的`scripts`文件夹

编辑`uosc_history.conf`并放入你的`script-opts`文件夹


## 3. 添加uosc按钮

编辑`uosc.conf`，在`controls=`后面找到合适的位置添加`button:history`：

```
controls='menu,button:history,gap...',
```

可用的按钮:

 - `button:history`: 播放记录
 - `button:bookmarks`: 书签
 - `button:add_bookmarks`: 添加书签

<a id="Keybindings"></a>

## 4. 绑定快捷键

在你的`input.conf`中可添加以下快捷键:

```
r				script-binding uosc_history/history				#! 播放记录
Alt+r			script-binding uosc_history/enable_history		#! 禁用 播放记录
Ctrl+Alt+r		script-binding uosc_history/clear_history		#! 清空播放记录

d				script-binding uosc_history/bookmarks			#! 收藏夹
Ctrl+d			script-binding uosc_history/add_bookmarks		#! 添加收藏
Alt+d			script-binding uosc_history/toggle_quick_mark	#! 切换快速收藏模式
Ctrl+Alt+d		script-binding uosc_history/clear_bookmarks		#! 清空收藏夹
```


--- 

## 参考了以下项目:  
- [uosc](https://github.com/tomasklaen/uosc)
- [SimpleHistory](https://github.com/dyphire/Eisa01_mpv-scripts/blob/dev/scripts/simplehistory.lua)
- [history-bookmark.lua](https://github.com/yuukidach/mpv-scripts/blob/master/README.zh-CN.md#history-bookmarklua)
- [uosc_danmaku](https://github.com/Tony15246/uosc_danmaku)
- [mpv\_PlayKit](https://github.com/hooke007/mpv_PlayKit)

  
