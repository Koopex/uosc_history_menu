[![Static Badge](https://img.shields.io/badge/README-English-blue)](./README.md)

# uosc_history_menu

为 mpv 增加一个与 [uosc](https://github.com/tomasklaen/uosc) 集成的播放历史与收藏管理菜单。

# 主要功能

## 1. 播放记录

### 播放记录筛选

打开菜单时，使用 `←/→ 方向键` 快速切换筛选方式。

| 筛选方式 | 说明 | 提示信息 | 删除范围 |
| --- | --- | --- | --- |
| 全部记录 | 同一视频可能有多个不同进度的条目 | 播放日期 时间 | 仅删除当前选中的单条记录 |
| 播放记录 | 每个视频只显示最新一条记录 | 已播 / 总时长 | 删除该视频的全部记录 |
| 按文件夹 | 每个文件夹一条最新记录 | 已看 / 文件夹内总数 | 删除该文件夹内所有视频的记录 |

## 2. 继续播放

- **一键恢复**：mpv 空闲时，按下 **播放/暂停键** 即可恢复上次观看的视频。
- **启动自动恢复**：设置 `startup_action=resume` 后，启动 mpv 时自动恢复上次视频。
- **同文件夹续播**：设置 `resume_in_folder=yes` 后，打开文件时若同文件夹内有其他视频的播放记录，弹窗提示是否跳转续播。

## 3. 收藏夹

- **添加收藏**：将任意播放记录或当前播放的视频添加为收藏。
  - **快速收藏**：直接添加到默认收藏夹，使用 `script-binding uosc_history/toggle_quick_mark` 切换。
- **其他操作**：
  | | 分组 | 收藏项 |
  | --- | --- | --- |
  | 删除 | 只能使用快捷键 `Del` | 快捷键或按钮 |
  | 排序 | 上移：`Ctrl+Up/PgUp/Home`<br>下移：`Ctrl+Down/PgDn/End` | 同左 |
  | 重命名 | 只能使用快捷键 `← 方向键` | `→ 方向键` 或按钮 |
  | 移动 | — | 按钮 |

# 使用方法

## 1. 安装 [uosc](https://github.com/tomasklaen/uosc)

## 2. 安装本插件

将 `uosc_history` 文件夹放入 `scripts` 目录。

将 `uosc_history.conf` 放入 `script-opts` 目录。

## 3. 添加 uosc 按钮

在 `uosc.conf` 的 `controls=` 后面添加按钮：

```
controls=menu,button:history,gap...,
```

可用按钮：
- `button:history`：播放记录
- `button:bookmarks`：收藏夹
- `button:add_bookmarks`：添加收藏

<a id="Keybindings"></a>

## 4. 绑定快捷键

在 `input.conf` 中添加：

```
r               script-binding uosc_history/history             #! 播放记录
Ctrl+r          script-binding uosc_history/enable_history      #! 开关播放记录
Ctrl+Alt+r      script-binding uosc_history/clear_history       #! 清空播放记录

d               script-binding uosc_history/bookmarks           #! 收藏夹
Ctrl+d          script-binding uosc_history/add_bookmarks       #! 添加收藏
Alt+d           script-binding uosc_history/toggle_quick_mark   #! 快速收藏
Ctrl+Alt+d      script-binding uosc_history/clear_bookmarks     #! 清空收藏夹
```

---

## 参考项目

- [uosc](https://github.com/tomasklaen/uosc)
- [SimpleHistory](https://github.com/dyphire/Eisa01_mpv-scripts/blob/dev/scripts/simplehistory.lua)
- [history-bookmark.lua](https://github.com/yuukidach/mpv-scripts/blob/master/README.zh-CN.md#history-bookmarklua)
- [uosc_danmaku](https://github.com/Tony15246/uosc_danmaku)
- [mpv_PlayKit](https://github.com/hooke007/mpv_PlayKit)
