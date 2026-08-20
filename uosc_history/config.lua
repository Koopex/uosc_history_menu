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
    -- 标题用上层目录；URL 始终按域名分组不受影响）
    source_view_flat = false,

    -- 搜索结果按播放时间排序
    search_sorting = false,

    -- 历史记录条目操作按钮（逗号分隔，按显示顺序；留空不显示按钮，但快捷键仍可用）
    -- 可用值：mark（收藏）,delete（删除）,playlist（添加到播放列表）,copy（复制）
    -- 分组语法：[delete,playlist] 会把组内操作折叠为一个“更多操作”按钮；空分组 [] 等效于自动补充未显示的操作
    history_actions = 'mark,delete,[]',

    -- 收藏条目操作按钮（逗号分隔，按显示顺序；留空 = 不显示按钮，快捷键仍可用）
    -- 可用值：new_group（新建分组）,rename（重命名）,move（移动）,copy（复制）,cut（剪切）,paste（粘贴）,delete（删除）,playlist（添加到播放列表）
    -- 分组语法：[move,copy,cut] 会把组内操作折叠为一个“更多操作”按钮；空分组 [] 等效于自动补充未显示的操作
    bookmark_actions = 'rename,delete,[]',

    -- 从收藏菜单点击条目时，把所在收藏分组加入播放列表并连播
    -- 可用值：no（关闭，默认）、siblings（只加入同级条目）、subtree（加入整棵子树的条目）
    bookmark_play_group = 'no',

    -- 收藏夹每层顶部显示"新建分组"按钮
    bookmark_new_group_button = false,

    -- 历史记录最大保存条数（0 = 不限制，默认值；设为正数后超出部分裁掉最旧记录）
    max_entries = 0,

    -- 日志文件路径（~~/ = 用户 home 目录）
    data_path = '~~/uosc_history.json',

    -- 收藏夹独立存储文件路径；留空则与历史记录存于同一文件（data_path）
    bookmark_path = '',
}

local M = {}

-- 所有可用的操作按钮名称（未知名称在解析时被过滤）
local known_actions = { mark = true, delete = true, rename = true, copy = true, cut = true, paste = true, move = true, new_group = true, playlist = true }

--- 解析逗号分隔的操作按钮列表：支持分组语法 [a,b,c]（组内操作折叠为“更多操作”按钮；空分组 [] 等效于 more）
--- 返回 token 数组：字符串 = 单按钮；table = 分组（空表表示自动补充未显示的操作）
local function parse_actions(str)
    local list = {}
    if type(str) ~= 'string' then return list end
    local pos, len = 1, #str
    while pos <= len do
        local c = str:sub(pos, pos)
        if c == '[' then
            local close = str:find(']', pos + 1, true)
            if not close then break end
            local content = str:sub(pos + 1, close - 1)
            local group = {}
            for name in content:gmatch('[^%[%],%s]+') do
                if known_actions[name] then group[#group + 1] = name end
            end
            -- 空分组 []（或仅含空白）留下作为空表（自动补充）；全部为未知项的分组直接忽略
            if content:match('%S') then
                if #group > 0 then list[#list + 1] = group end
            else
                list[#list + 1] = group
            end
            pos = close + 1
        elseif c == ',' or c:match('%s') then
            pos = pos + 1
        else
            local name = str:match('[^,%s]+', pos)
            if not name then break end
            if known_actions[name] then list[#list + 1] = name end
            pos = pos + #name
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
