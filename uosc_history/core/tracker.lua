-- 播放追踪器：捕获文件加载时的元数据，处理同文件夹续播，卸载时完成条目

local M = {}

local mp = require('mp')
local utils_mod = require('mp.utils')
local script_name = mp.get_script_name()

local config = {}
local I18N      -- i18n 字符串
local storage = nil
local history = nil
local utils = nil -- 我们的工具模块

-- 当前正在构建的条目
local new_entry = nil

-- 状态标志
local loaded = false      -- 首次 file-loaded 后为 true，防止重复触发 resume_in_folder
local from_record = false -- 通过历史/收藏菜单加载时为 true
local auto_next = false   -- 自动跳转下一集后，跳过本次同文件夹检查
local group_playlist = false -- 脚本构建的分组连播播放中：抑制"同文件夹续播"提示
-- 同文件夹续播提示：每个 mpv 会话只检查一次，避免播放下一集时反复提示续播上一集
local resume_prompted = false

--- 路径是否相同（忽略分隔符形式差异：\\ 与 / 视为等价）
local function same_path(a, b)
    return a and b and a:gsub('\\', '/') == b:gsub('\\', '/')
end

--- 注入依赖
function M.init(params)
    config = params.config
    I18N = params.i18n
    storage = params.storage
    history = params.history
    utils = params.utils
end

function M.get_new_entry()
    return new_entry
end

function M.set_from_record(val)
    from_record = val
end

--- 新文件加载时调用，开始构建条目
function M.on_file_loaded()
    if not config.log then return end

    new_entry = {}
    new_entry.media_title = mp.get_property('media-title', '')
    new_entry.datetime = os.date('%Y/%m/%d  %H:%M')
    new_entry.path = mp.get_property('path', '')
    new_entry.duration = math.floor(mp.get_property_number('duration', 0))


    if utils.is_url(new_entry.path) then
        M._handle_url()
        loaded = true
    else
        M._handle_local_file()
        loaded = true
    end
    -- from_record/auto_next 只对本次加载生效：end-file 不会清除它们，
    -- 必须在这里消费掉，否则会漏到下一个文件（导致续播菜单点击后循环提示）
    from_record = false
    auto_next = false
end

--- 播放中启用记录时捕获当前文件
function M.capture_current()
    if not config.log then return end
    if next(new_entry or {}) then return end
    if mp.get_property_bool('idle-active', 'false') then return end
    M.on_file_loaded()
end

--- 处理 URL 条目（流媒体）
function M._handle_url()
    new_entry.url = true

    local found_referer = false
    local headers = mp.get_property('options/http-header-fields', '')
    if headers ~= '' then
        for part in string.gmatch(headers, '([^,]+)') do
            if type(part) == 'string' then
                local key, value = part:match('^%s*(.-)%s*:%s*(.-)%s*$')
                if key and value and key:lower():match('^referer$') and value:match('^http') then
                    new_entry.path = value
                    found_referer = true
                    break
                end
            end
        end
    end

    if not found_referer then
        for _, track in ipairs(mp.get_property_native('track-list')) do
            if track['type'] == 'audio' and track['external'] then
                new_entry.audio_path = track['external-filename']
            end
        end
    end

    -- 追踪直播流时长
    local twice = false
    local function ob_duration(_, d)
        if d and twice then
            new_entry.live = true
            mp.unobserve_property(ob_duration)
        end
        twice = true
        mp.add_timeout(3, function() mp.unobserve_property(ob_duration) end)
    end
    mp.observe_property('duration', 'number', ob_duration)
end

--- 续播提示的进度文本
local function entry_hint(entry)
    if entry.live then return I18N.live end
    if entry.duration and entry.duration > 0 then
        return utils.format_time(entry.pos or 0) .. ' / ' .. utils.format_time(entry.duration)
    end
    return ''
end

--- 构造“从头播放下一集”的目标条目
local function build_next_target(next_path)
    local _, next_name = utils_mod.split_path(next_path)
    local next_item = history.get_dedup_by_path(next_path)
    return {
        path = next_path,
        media_title = next_name,
        pos = 0,
        duration = next_item and next_item.value and next_item.value.duration,
        url = false,
        audio_path = nil,
    }
end

--- 弹出同文件夹续播菜单，并标记对应历史条目
local function show_resume_menu(target, target_hint, target_is_next, peer)
    local menu_props = {
        title = I18N.resume_in_folder,
        selected_index = 1,
        items = {
            {
                title = target.media_title,
                hint = target_hint,
                active = true,
                icon = 'history',
                value = {
                    path = target.path,
                    pos = target.pos,
                    duration = target.duration,
                    url = target.url,
                    audio_path = target.audio_path,
                    media_title = target.media_title,
                    auto_next = target_is_next,
                },
            },
            {
                title = new_entry.media_title,
                hint = I18N.now,
                muted = true,
                selectable = false,
                icon = '',
                italic = true,
            },
        },
        callback = { script_name, 'history_menu_event' },
    }
    mp.commandv('script-message-to', 'uosc', 'open-menu', utils_mod.format_json(menu_props))

    local all_view = history.get_view('all')
    local peer_all = all_view[peer]
    if peer_all then
        peer_all.icon = 'history'
        peer_all.actions_place = 'outside'
    end
    local dedup_view = history.get_view('recent')
    if peer_all and peer_all.dedup_index then
        local peer_dedup = dedup_view[peer_all.dedup_index]
        if peer_dedup then
            peer_dedup.icon = 'history'
            peer_dedup.actions_place = 'outside'
        end
    end
end

--- 处理本地文件条目
function M._handle_local_file()
    if auto_next then
        auto_next = false
    elseif not loaded and not from_record and not resume_prompted and not group_playlist and config.resume_in_folder then
        -- 每个 mpv 会话只检查一次，避免播放下一集时反复提示续播上一集
        resume_prompted = true
        -- 立即检查是否需要续播；“续播下一集”直接 readdir 扫描目录，无需等播放列表
        M._check_resume_in_folder()
    end
end

--- 检查同文件夹是否有其他视频可续播
function M._check_resume_in_folder()
    local raw_entries = history.get_entries()
    local new_upper = utils and utils.get_folder_info and utils.get_folder_info(new_entry.path, utils_mod)

    -- 原始条目最新在前：取与当前文件同目录的第一条（最新）记录判断续播
    for peer, entry in ipairs(raw_entries) do
        if entry.path and entry.path ~= '' then
            local entry_upper = utils and utils.get_folder_info and utils.get_folder_info(entry.path, utils_mod)

            -- 路径分隔符归一化后比较（mpv 与记录的路径形式可能不同：\ vs /）
            if same_path(new_upper, entry_upper) then
                -- 默认提示恢复该记录；若已播进度超过重播阈值，则优先提示播放该文件夹中的下一个视频（从头）。
                -- 打开的就是该记录本身时同样适用：进度已看完则提示从头播放下一集
                local progress = 0
                if entry.duration and entry.duration > 0 then
                    progress = (entry.pos or 0) / entry.duration * 100
                end
                if progress > (config.restart_threshold or 90) then
                    M._offer_resume_next(entry, peer)
                elseif new_entry.path ~= entry.path then
                    show_resume_menu(entry, entry_hint(entry), false, peer)
                end
                break
            end
        end
    end
end

--- 续播目标需要“下一集”时：用 readdir 直接扫描记录所在目录；
--- 扫描失败或记录不在目录中时退回“恢复该集”提示
function M._offer_resume_next(entry, peer)
    local next_path, found = M._find_next_in_folder(entry)
    if next_path then
        show_resume_menu(build_next_target(next_path), I18N.from_start, true, peer)
        return
    end
    if found then return end -- 扫描成功且该集是最后一个媒体文件：不提示
    -- 无法确认下一集：按“快要播完的那集”提示恢复；打开的就是该记录本身时不提示
    if not same_path(entry.path, new_entry.path) then
        show_resume_menu(entry, entry_hint(entry), false, peer)
    end
end

--- 自然比较（数字段按数值大小）：让 "E9" 排在 "E10" 之前
local function natural_less(a, b)
    local function sort_key(s)
        return (s:gsub('%d+', function(d)
            return string.format('%09d', tonumber(d))
        end))
    end
    return sort_key(a) < sort_key(b)
end


--- 常见媒体扩展名（视频+音频），readdir 扫描时筛选“下一集”候选
local MEDIA_EXTS = {}
for _, ext in ipairs({
    '3g2', '3gp', 'avi', 'flv', 'm2ts', 'm4v', 'mj2', 'mkv', 'mov',
    'mp4', 'mpeg', 'mpg', 'ogv', 'rmvb', 'webm', 'wmv', 'y4m',
    'aiff', 'ape', 'au', 'flac', 'm4a', 'mka', 'mp3', 'oga', 'ogg',
    'ogm', 'opus', 'wav', 'wma',
}) do
    MEDIA_EXTS[ext] = true
end

--- 是否为媒体文件（按扩展名判断，排除字幕、文本等干扰项）
local function is_media_file(name)
    local ext = name:match('%.([^%.\\/]+)$')
    return ext ~= nil and MEDIA_EXTS[ext:lower()] ~= nil
end

--- 用 readdir 扫描记录所在目录，把同目录媒体文件按文件名自然排序，
--- 返回该记录之后的第一项路径；不依赖播放列表/autoload。
--- 返回 next_path 与 found（true = 扫描成功且可确认没有下一集）
function M._find_next_in_folder(entry)
    if not entry or not entry.path or entry.url then return nil, false end
    local dir_path, name = utils_mod.split_path(entry.path)
    if dir_path == '' or dir_path == '.' then return nil, false end
    local names, err = utils_mod.readdir(dir_path, 'files')
    if not names then return nil, false end
    local files = {}
    for _, n in ipairs(names) do
        if is_media_file(n) then files[#files + 1] = n end
    end
    if #files == 0 then return nil, false end
    table.sort(files, natural_less)
    for i = 1, #files do
        if files[i]:lower() == name:lower() then
            local nxt = files[i + 1]
            if not nxt then return nil, true end -- 已是最后一个媒体文件：不提示
            local nxt_path = dir_path .. nxt
            if same_path(nxt_path, new_entry.path) then return nil, true end -- 下一集就是当前文件
            return nxt_path, true
        end
    end
    -- 记录对应的文件已不在目录中（被移动/删除）：无法确认下一集，退回恢复提示
    return nil, false
end

--- 标记即将加载的文件是自动跳转的下一集（加载后跳过本次同文件夹检查）
function M.set_auto_next(val)
    auto_next = val or false
end

--- 标记分组连播是否激活（抑制"同文件夹续播"提示）
function M.set_group_playlist(val)
    group_playlist = val or false
end

--- end-file 时调用：完成条目并插入历史
function M.on_end_file()
    if not config.log then
        new_entry = {}
        return
    end
    if new_entry and next(new_entry) then
        history.add(new_entry)
    end
    new_entry = {}
    loaded = false
end

--- on_unload 钩子：捕获最终播放位置
function M.on_unload(hook)
    if not new_entry then new_entry = {} end
    if not next(new_entry) then return end
    local pos = mp.get_property_number('time-pos', 0)
    if pos >= 3 then
        new_entry.pos = math.floor(pos - 3)
    else
        new_entry.pos = 0
    end
end

--- 清空新条目（禁用记录时）
function M.clear_new_entry()
    new_entry = {}
end

--- 加载文件辅助函数：有播放位置时传 start，否则不传（恢复交给 watch_later 或从头播放）；
--- 标题与外挂音轨用 %N% 定长编码直接放进 loadfile 每文件选项，随文件生命周期自动生效/失效，无需手动清理
function M.load_file(params)
    from_record = true
    group_playlist = false -- 新的脚本加载会重建播放上下文，清除分组连播抑制
    local opts = {}
    if params.pos ~= nil then
        opts[#opts + 1] = 'start=' .. params.pos
    end
    if params.media_title and params.media_title ~= '' then
        opts[#opts + 1] = utils.loadfile_title_option(params.media_title)
    end
    if params.audio_path then
        opts[#opts + 1] = 'audio-files=' .. utils.loadfile_value_option(params.audio_path)
    end
    local cmd = { 'loadfile', params.path, 'replace', -1 }
    if #opts > 0 then
        cmd[5] = table.concat(opts, ',')
    end
    mp.command_native(cmd)
end

-- 分组连播播放列表结束（进入 idle）时清除抑制标记
mp.observe_property('idle-active', 'bool', function(name, val)
    if val then group_playlist = false end
end)

return M


