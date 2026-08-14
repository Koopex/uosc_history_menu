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

    -- 按来源分组视图：true = 扁平分组（本地文件每组只显示最新一条，
    -- 标题用上层目录，hint 用集内位置；URL 始终按域名分组不受影响）
    source_view_flat = false,

    -- 搜索结果按播放时间排序
    search_sorting = false,

    -- 收藏夹每层顶部显示"新建分组"按钮
    bookmark_new_group_button = false,

    -- 历史记录条目操作按钮（逗号分隔，按显示顺序；留空 = 不显示按钮，快捷键仍可用）
    -- 可用值：mark（收藏）、copy（复制）、delete（删除）
    history_actions = 'mark,delete',

    -- 收藏条目操作按钮（逗号分隔，按显示顺序；留空 = 不显示按钮，快捷键仍可用）
    -- 可用值：rename（重命名）、copy（复制）、cut（剪切）、paste（粘贴）、move（移动）、delete（删除）
    bookmark_actions = 'rename,move,delete',

    -- 日志文件路径（~~/ = 用户 home 目录）
    data_path = '~~/uosc_history.json',

    -- 收藏夹独立存储文件路径；留空则与历史记录存于同一文件（data_path）
    bookmark_path = '',

    -- 历史记录最大保存条数（0 = 不限制，默认值；设为正数后超出部分裁掉最旧记录）
    max_entries = 0,
}

local M = {}

-- 所有可用的操作按钮名称（未知名称在解析时被过滤）
local known_actions = { mark = true, delete = true, rename = true, copy = true, cut = true, paste = true, move = true }

--- 解析逗号分隔的操作按钮列表：过滤未知名称，返回按显示顺序排列的数组
local function parse_actions(str)
    local list = {}
    if type(str) == 'string' then
        for name in str:gmatch('[^,%s]+') do
            if known_actions[name] then list[#list + 1] = name end
        end
    end
    return list
end

--- 读取配置，应用 mpv script-opts 覆盖
function M.read(script_name)
    local mp = require('mp')
    local options = require('mp.options')
    local config = {}
    for k, v in pairs(defaults) do
        config[k] = v
    end
    options.read_options(config, script_name)
    config.history_actions = parse_actions(config.history_actions)
    config.bookmark_actions = parse_actions(config.bookmark_actions)
    return config
end

--- 展开日志路径（处理 ~~/ 和 ~~home 等 mpv 路径前缀）
function M.expand_path(path)
    local mp = require('mp')
    path = mp.command_native({'expand-path', path})
    return path
end

return M
