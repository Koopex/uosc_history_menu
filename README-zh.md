[![Static Badge](https://img.shields.io/badge/README-English-blue)](./README.md)

# uosc_history_menu

为 mpv 增加一个与 [uosc](https://github.com/tomasklaen/uosc) 深度集成的播放历史与收藏管理菜单。

- 记录播放历史，支持三种筛选视图
- 续播：一键恢复、启动自动恢复、同文件夹续播
- 收藏夹支持任意层级分组，可通过剪贴板导入/导出
- 可将历史记录和收藏条目加入播放列表，或收藏当前播放列表

---

## 播放记录

每次播放都会记录路径、标题、进度、时长和时间。打开历史菜单（默认 `r`）即可浏览。

### 筛选视图

打开菜单时，用 `←` / `→` 方向键切换视图。

| 视图 | 说明 | 提示信息 | 删除范围 |
| --- | --- | --- | --- |
| **全部记录** | 每条记录都保留；同一视频可能在不同进度下出现多次 | 播放时间 | 仅删除当前选中的单条记录 |
| **播放记录** | 每个视频只保留最新一条记录 | 已播 / 总时长 | 删除该视频的全部记录 |
| **按来源分组** | 本地文件按文件夹、URL 按域名/IP 分组，以子菜单展示 | 已播 / 总时长 | 删除该文件夹 / 域名下的全部记录 |

> **按来源分组**：默认按文件夹/域名嵌套子菜单展示；设置 `source_view_flat=yes` 后，本地文件改为扁平分组（每个文件夹只保留最新一条记录）；URL 始终按域名/IP 分组。

### 搜索

按 `Ctrl+f` 可搜索当前历史记录。设置 `search_sorting=yes` 后，搜索结果按最近播放时间排序，而不是 uosc 的默认顺序。

### 条目图标

条目前面带类型图标：`🔗` URL、`🎬` 本地文件、`📁` 文件夹。

---

## 续播

- **一键恢复** —— mpv 空闲时，按**播放/暂停键**即可恢复最近一次播放的文件。
- **启动自动恢复** —— 设置 `startup_action=resume` 后启动自动恢复上次文件；`startup_action=menu` 则启动时打开历史菜单。
- **同文件夹续播** —— 设置 `resume_in_folder=yes` 后，打开文件时若同文件夹内有其他视频的播放记录，弹窗提示是否跳转续播；若最新记录的进度超过 `restart_threshold`，则提示续播该文件夹内的**下一个文件**（从头播放）。
- **重播阈值** —— 从历史记录打开条目时，若已播进度超过 `restart_threshold`（默认 `90`%），则从头播放。`0` 始终从头播放，`100` 始终恢复进度。

---

## 收藏夹

### 分组

分组内可以继续创建子分组（不限层级），文件夹与条目可以自由混合。打开收藏菜单（默认 `d`）进行管理。

### 添加收藏

- 从历史记录收藏（在历史菜单选中条目后按 `Ctrl+d`）
- 收藏当前正在播放的视频（不在菜单内时按默认 `Ctrl+d`）
- 收藏当前播放列表（默认 `Ctrl+D`）
- 粘贴路径、URL 或手写 JSON 结构（见下文）

**快速收藏模式**（`Alt+d`）会把条目直接添加到*快速收藏*分组，无需选择收藏位置。

### 条目操作

| 操作 | 快捷键 | 说明 |
| --- | --- | --- |
| 删除 | `Del` | 删除选中的条目 |
| 重命名 | `F2` | 重命名选中条目（自动填入原名称） |
| 新建分组 | `Ctrl+n` | 在当前层级新建分组 |
| 排序 | `Ctrl+Home/End/PgUp/PgDw/↑/↓` | 调整当前层级内条目的顺序 |
| 移动 | `Ctrl+m` | 把条目移动到指定位置 |
| 复制 / 剪切 | `Ctrl+c` / `Ctrl+x` | 把条目以 JSON 格式复制/剪切到剪贴板 |
| 粘贴 / 导入 | `Ctrl+v` | 粘贴到当前选中条目下方 |
| 添加到播放列表 | `Ctrl+p` | 把条目（或分组）追加到播放列表 |

### 粘贴与导入

1. 纯**路径或 URL** —— 会弹窗提示输入标题，然后作为收藏条目添加。
2. 从**历史记录或收藏夹复制**的条目 —— 插入到当前选中条目下方；粘贴时会检查当前层级内是否重复。
3. 手写的 **JSON 数组/表** —— 条目需要 `title` 和 `path` 字段；分组需要 `title` 和 `items`（数组）字段。按顺序逐个插入，无效条目会被跳过。

---

## 播放列表

- **添加到播放列表**（`Ctrl+p` / *添加到播放列表*按钮）把历史记录和收藏条目追加到播放列表，不打断当前播放。追加的条目会带上标题，即使是没有元数据的 URL 或文件，播放列表也能清晰可读。
- **分组连播** —— 设置 `bookmark_play_group=siblings` 或 `subtree` 后，点击收藏条目会把所在分组加入播放列表连播：`siblings` 只加入同层级的条目，`subtree` 把整棵嵌套分组展平。点击的条目从保存的进度开始播放，其余条目按菜单顺序从头播放。
- **收藏当前播放列表**（`Ctrl+D` / *收藏播放列表*按钮）把整个播放列表保存到一个分组中（非快速收藏模式下可选择保存位置）。

---

## 配置

编辑 `script-opts/uosc_history.conf`：

| 配置项 | 默认值 | 说明 |
| --- | --- | --- |
| `language` | `zh` | 界面语言：`zh` 或 `en` |
| `startup_action` | `none` | 启动动作：`resume` / `menu` / `none` |
| `resume_in_folder` | `no` | 同文件夹内有其他记录时提示续播 |
| `restart_threshold` | `90` | 已播进度超过该百分比时从头播放 |
| `use_filename` | `no` | 使用文件名而非媒体标题 |
| `source_view_flat` | `no` | "按来源分组"视图：`yes` = 扁平分组（每组只保留最新一条记录），`no` = 嵌套子菜单 |
| `search_sorting` | `no` | 搜索结果按播放时间排序 |
| `history_actions` | `mark,delete` | 历史记录条目操作按钮（逗号分隔、按显示顺序；留空不显示按钮，快捷键仍可用） |
| `bookmark_actions` | `rename,delete,[]` | 收藏条目操作按钮（逗号分隔、按显示顺序；留空不显示按钮，快捷键仍可用） |
| `bookmark_new_group_button` | `no` | 收藏夹每层顶部显示"新建分组"按钮 |
| `bookmark_play_group` | `no` | 点击收藏条目时把所在分组加入播放列表连播：`no` / `siblings` / `subtree` |
| `max_entries` | `0` | 播放记录最多保存条数（`0` = 不限制） |
| `data_path` | `~~/uosc_history.json` | 播放记录数据文件 |
| `bookmark_path` | *(空)* | 收藏夹独立文件；留空则与记录存于同一文件 |

### 操作按钮

- 历史记录：`mark`（收藏）、`delete`（删除）、`playlist`（添加到播放列表）、`copy`（复制）。
- 收藏条目：`new_group`（新建分组）、`rename`（重命名）、`move`（移动）、`copy`（复制）、`cut`（剪切）、`paste`（粘贴）、`delete`（删除）、`playlist`（添加到播放列表）。
- 分组语法 `[a,b,c]` 会把组内操作折叠为一个**更多操作**按钮；空分组 `[]` 自动补充未显示为按钮的操作。

---

## 使用方法

1. **安装 [uosc](https://github.com/tomasklaen/uosc)**。
2. **安装本插件** —— 把 `uosc_history` 文件夹放入 `scripts` 目录，把 `uosc_history.conf` 放入 `script-opts` 目录。
3. **添加 uosc 按钮** —— 在 `uosc.conf` 的 `controls=` 中添加按钮：

   ```
   controls=menu,button:history,gap...,
   ```

   可用按钮：
   - `button:history` —— 播放记录
   - `button:bookmarks` —— 收藏夹
   - `button:add_bookmarks` —— 添加收藏
   - `button:add_playlist` —— 收藏播放列表

4. **绑定快捷键** —— 在 `input.conf` 中添加：

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

## 数据存储

历史和收藏都保存为纯 JSON 文件，方便备份或手动编辑：

- `data_path` —— 播放记录（默认 `~~/uosc_history.json`）。
- `bookmark_path` —— 可选的独立收藏文件；留空时收藏与记录存于同一文件。

---

## 参考项目

- [uosc](https://github.com/tomasklaen/uosc)
- [SimpleHistory](https://github.com/dyphire/Eisa01_mpv-scripts/blob/dev/scripts/simplehistory.lua)
- [history-bookmark.lua](https://github.com/yuukidach/mpv-scripts/blob/master/README.zh-CN.md#history-bookmarklua)
- [uosc_danmaku](https://github.com/Tony15246/uosc_danmaku)
- [mpv_PlayKit](https://github.com/hooke007/mpv_PlayKit)