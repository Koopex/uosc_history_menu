-- uosc_history_menu 配置默认值
-- 可通过 mpv 的 script-opts 机制覆盖

local defaults = {
    -- 语言：'zh' 或 'en'
    language = 'zh',

    -- 启动动作：'resume' | 'menu' | 'none'
    startup_action = 'none',

    -- 同文件夹续播提示
    resume_in_folder = false,

    -- 重播阈值：点击历史条目时，已播进度超过该百分比则从头播放（0 = 始终从头播放；100 = 始终恢复进度）
    restart_threshold = 90,

    -- 使用文件名而非媒体标题
    use_filename = false,

    -- 搜索结果按播放时间排序
    search_sorting = false,

    -- 日志文件路径（~~/ = 用户 home 目录）
    data_path = '~~/uosc_history.json',
}

local M = {}

--- 读取配置，应用 mpv script-opts 覆盖
function M.read(script_name)
    local mp = require('mp')
    local options = require('mp.options')
    local config = {}
    for k, v in pairs(defaults) do
        config[k] = v
    end
    options.read_options(config, script_name)
    return config
end

--- 展开日志路径（处理 ~~/ 和 ~~home 等 mpv 路径前缀）
function M.expand_path(path)
    local mp = require('mp')
    path = mp.command_native({'expand-path', path})
    return path
end

return M
