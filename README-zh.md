[![Static Badge](https://img.shields.io/badge/README-English-blue)](./README.md)

# uosc_history_menu

为 mpv 增加一个与 [uosc](https://github.com/tomasklaen/uosc) 集成的播放历史与收藏管理菜单。

# 主要功能

## 1. 播放记录

### 播放记录筛选

打开菜单时，使用 `←/→ 方向键` 切换筛选方式（全部记录 ↔ 播放记录 ↔ 按来源分组）。

| 筛选方式 | 说明 | 提示信息 | 删除范围 |
| --- | --- | --- | --- |
| 全部记录 | 同一视频可能有多个不同进度的条目 | 播放日期 时间 | 仅删除当前选中的单条记录 |
| 播放记录 | 每个视频只显示最新一条记录 | 已播 / 总时长 | 删除该视频的全部记录 |
| 按来源分组 | 本地文件按文件夹、URL 按域名/IP 分组，以子菜单展示 | 已播 / 总时长 | 删除该文件夹/域名下的全部记录 |

### 条目图标

条目前面带类型图标：`🔗` URL、`🎬` 本地文件、`📁` 文件夹。

## 2. 继续播放

- **一键恢复**：mpv 空闲时，按下 **播放/暂停键** 即可恢复上次观看的视频。
- **启动自动恢复**：设置 `startup_action=resume` 后，启动 mpv 时自动恢复上次视频。
- **同文件夹续播**：设置 `resume_in_folder=yes` 后，打开文件时若同文件夹内有其他视频的播放记录，弹窗提示是否跳转续播；若最新记录的进度超过 `restart_threshold`，则提示续播该文件夹内的下一个文件（从头播放）。   
> **重播阈值**：从播放记录打开时，若已播进度超过 `restart_threshold`（默认 90%），则从头播放；`0` 始终从头，`100` 始终恢复进度。

## 3. 收藏夹

- **分组**：分组内可继续创建子分组（不限层级），可混合文件夹与条目。
- **添加收藏**：可添加播放记录、当前视频、当前播放列表，也可以通过剪切板导入。
  - **快速收藏模式**：使用快捷键切换模式，快速收藏模式下直接添加到快速收藏夹，无需选择收藏位置。
- **条目操作**：
  | 操作 | 快捷键 | 说明 |
  | --- | --- | --- |
  | 删除 | `Del` |  |
  | 重命名 | `F2` |  |
  | 排序 | `Ctrl+Home/End/PgUp/PgDw/↑/↓` |  |
  | 复制 / 剪切 | `Ctrl+c` / `Ctrl+x` | 把条目信息复制到剪切板（JSON 格式） |
  | 粘贴 / 导入 | `Ctrl+v` | 需要打开收藏夹，在当前选择的条目下方导入<br>1. 粘贴路径或 URL，按提示输入名称以后完成收藏<br>2. 从播放记录或收藏夹复制条目，到收藏夹合适的位置粘贴<br>3. 手写 JSON 数组/表 导入。条目需要的字段：`title`、`path`；分组需要的字段 ：`title`、`items`(数组)

# 配置

编辑 `script-opts/uosc_history.conf`：

| 配置项 | 默认值 | 说明 |
| --- | --- | --- |
| `language` | `zh` | 界面语言：`zh` 或 `en` |
| `startup_action` | `none` | 启动动作：`resume` / `menu` / `none` |
| `resume_in_folder` | `no` | 同文件夹内有其他记录时提示续播 |
| `restart_threshold` | `90` | 已播进度超过该百分比时从头播放 |
| `use_filename` | `no` | 使用文件名而非媒体标题 |
| `search_sorting` | `no` | 搜索结果按播放时间排序 |
| `max_entries` | `0` | 播放记录最多保存条数（`0` = 不限制） |
| `data_path` | `~~/uosc_history.json` | 播放记录数据文件 |
| `bookmark_path` | *(空)* | 收藏夹独立文件；留空则与记录存于同一文件 |

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
- `button:add_playlist`：收藏播放列表

<a id="Keybindings"></a>

## 4. 绑定快捷键

在 `input.conf` 中添加：

```
r               script-binding uosc_history/history             #! 播放记录
Ctrl+r          script-binding uosc_history/enable_history      #! 开关播放记录
Ctrl+Alt+r      script-binding uosc_history/clear_history       #! 清空播放记录

d               script-binding uosc_history/bookmarks           #! 收藏夹
Ctrl+d          script-binding uosc_history/add_bookmarks       #! 添加收藏
Ctrl+D          script-binding uosc_history/add_playlist        #! 收藏播放列表
Alt+d           script-binding uosc_history/toggle_quick_mark   #! 切换 快速收藏模式
Ctrl+Alt+d      script-binding uosc_history/clear_bookmarks     #! 清空收藏夹
```

---

## 参考项目

- [uosc](https://github.com/tomasklaen/uosc)
- [SimpleHistory](https://github.com/dyphire/Eisa01_mpv-scripts/blob/dev/scripts/simplehistory.lua)
- [history-bookmark.lua](https://github.com/yuukidach/mpv-scripts/blob/master/README.zh-CN.md#history-bookmarklua)
- [uosc_danmaku](https://github.com/Tony15246/uosc_danmaku)
- [mpv_PlayKit](https://github.com/hooke007/mpv_PlayKit)
