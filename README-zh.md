中文|[English](https://github.com/Koopex/uosc_history_menu/blob/main/README.md)

# uosc_history_menu

在MPV播放器中添加基于uosc的播放记录。

# 主要功能

## 1. 播放记录

### 播放记录过滤

打开列表时可以按方向键←/→切换过滤方式。

|过滤方式 |说明 | 提示信息 |
| --- | --- | --- |
|全部记录| 每个视频可有多条不同时间记录 | 播放日期 时间 |
| 播放记录 | 每个视频一条记录 | 播放时长/总时长 |
| 文件夹记录 | 每个文件夹一条记录 | 已看视频数/总视频数 |

## 2. 恢复播放

### 一键恢复

空闲状态下"播放/暂停"即可

### 启动后立即恢复

- 需修改设置: `start_action=resume`

## 3. 提示同目录上次播放的视频

- 需修改设置: `resume_in_folder=yes`

例如，直接打开第2集`~~/TV-show/S01E02.mkv`, 而存在第17集的记录`~~/TV-show/S01E17.mkv`,
则弹出菜单提示继续播放第17集

# 使用方法

## 1. 安装[uosc](https://github.com/tomasklaen/uosc)

## 2. 添加uosc按钮

在uosc的script-opts中，在`controls=`后面找到合适的位置添加`button:history`：

```
controls='menu,button:history,gap...',
```

<a id="Keybindings"></a>

## 3. 绑定快捷键

在你的`input.conf`中可添加以下快捷键:

```
r               script-binding uosc_history/toggle_menu      #! 播放记录
Ctrl+r          script-binding uosc_history/clear            #! 清空播放记录
Ctrl+shift+r    script-binding uosc_history/toggle_log       #! 启用/禁用 播放记录
```

## 4. 其他设置(可选)

修改`uosc_history.conf`

# 感谢!

感谢以下项目提供参考!

- [mpv](https://github.com/mpv-player/mpv)
- [mpv\_PlayKit](https://github.com/hooke007/mpv_PlayKit)
- [uosc](https://github.com/tomasklaen/uosc)
- [uosc_danmaku](https://github.com/Tony15246/uosc_danmaku)
- [SimpleHistory](https://github.com/dyphire/Eisa01_mpv-scripts/blob/dev/scripts/simplehistory.lua)
- [外部播放器(Play-With-MPV)](https://github.com/LuckyPuppy514/external-player)
