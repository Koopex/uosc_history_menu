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
-- 同文件夹续播的“续播下一集”轮询：需要下一集但播放列表未就绪时使用
local resume_poll = nil
-- 脚本加载时设置的 force-media-title 是否仍在等待本次播放消费
local force_title_set = false
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

--- 轮询等待播放列表生成（autoload）后再取“下一集”；最多约 5 秒，
--- 超时则退回“恢复该集”提示
local function resume_next_tick()
    local poll = resume_poll
    if not poll then return end
    poll.timer = nil
    if new_entry ~= poll.current then
        resume_poll = nil -- 已切换到其他文件，放弃
        return
    end
    local next_path, found = M._find_next_in_folder(poll.entry)
    if next_path then
        resume_poll = nil
        show_resume_menu(build_next_target(next_path), I18N.from_start, true, poll.peer)
        return
    end
    if found then
        resume_poll = nil -- 播放列表已就绪且该集是最后一集：不提示
        return
    end
    if poll.ticks < 25 then
        poll.ticks = poll.ticks + 1
        poll.timer = mp.add_timeout(0.2, resume_next_tick)
        return
    end
    -- 轮询超时仍无播放列表：按“快要播完的那集”提示恢复；
    -- 打开的就是该记录本身时无法确认下一集，不提示
    resume_poll = nil
    if not same_path(poll.entry.path, new_entry.path) then
        show_resume_menu(poll.entry, entry_hint(poll.entry), false, poll.peer)
    end
end

--- 处理本地文件条目
function M._handle_local_file()
    if auto_next then
        auto_next = false
    elseif not loaded and not from_record and not resume_prompted and config.resume_in_folder then
        -- 每个 mpv 会话只检查一次，避免播放下一集时反复提示续播上一集
        resume_prompted = true
        -- 先立即检查是否需要续播；只有“续播下一集”才需要等播放列表就绪
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

--- 续播目标需要“下一集”时：立即查播放列表；未找到则轮询等待，
--- 列表就绪且该集是最后一集则不提示，轮询超时退回“恢复该集”提示
function M._offer_resume_next(entry, peer)
    local next_path, found = M._find_next_in_folder(entry)
    if next_path then
        show_resume_menu(build_next_target(next_path), I18N.from_start, true, peer)
        return
    end
    if found then return end -- 播放列表已就绪且该集是最后一集：不提示
    resume_poll = { entry = entry, current = new_entry, peer = peer, ticks = 0 }
    resume_next_tick()
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

--- 从播放列表中查找记录条目所在目录的下一个视频路径；
--- 不依赖播放列表顺序：把同目录文件按文件名自然排序，取该记录之后的第一项。
--- 返回 next_path 与 found（true = 播放列表已就绪且可确认没有下一集）
function M._find_next_in_folder(entry)
    if not entry or not entry.path or entry.url then return nil, false end
    local dir_path = utils_mod.split_path(entry.path)
    local playlist = mp.get_property_native('playlist')
    if not playlist then return nil, false end
    local same_dir = {}
    for _, item in ipairs(playlist) do
        if item and item.filename and item.filename ~= '' then
            local item_dir = utils_mod.split_path(item.filename)
            if same_path(item_dir, dir_path) then
                same_dir[#same_dir + 1] = item.filename
            end
        end
    end
    if #same_dir == 0 then return nil, false end
    table.sort(same_dir, natural_less)
    for i = 1, #same_dir do
        if same_path(same_dir[i], entry.path) then
            local nxt = same_dir[i + 1]
            if not nxt then
                -- 记录已是同目录最后一个文件：打开的就是该记录本身时，
                -- 播放列表可能还没被 autoload 补全，继续轮询；否则确认是最后一集
                if same_path(entry.path, new_entry.path) then return nil, false end
                return nil, true
            end
            if same_path(nxt, new_entry.path) then return nil, true end -- 下一集就是当前文件
            return nxt, true
        end
    end
    -- 记录条目不在播放列表里：列表未就绪，继续轮询
    return nil, false
end

--- 标记即将加载的文件是自动跳转的下一集（加载后跳过本次同文件夹检查）
function M.set_auto_next(val)
    auto_next = val or false
end

--- end-file 时调用：完成条目并插入历史
function M.on_end_file()
    if resume_poll and resume_poll.timer then
        mp.cancel_timer(resume_poll.timer)
    end
    resume_poll = nil
    -- 没有为下一个脚本加载预设标题时清理 force-media-title（避免残留污染非脚本加载的文件）；
    -- 已为下一个脚本加载预置标题时不清理，防止误清新文件的标题
    if not force_title_set then
        mp.set_property('force-media-title', '')
    end
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

--- 加载文件辅助函数：有播放位置时传 start，否则不传（恢复交给 watch_later 或从头播放）
function M.load_file(params)
    from_record = true
    -- loadfile 的选项参数是 key=value 字符串，值里含逗号/引号会破坏解析；
    -- 因此只把纯数字的 start 放进选项串，标题与外挂音轨改为加载后设置属性，彻底免转义
    local opts = {}
    if params.pos ~= nil then
        opts[#opts + 1] = 'start=' .. params.pos
    end
    local cmd = { 'loadfile', params.path, 'replace', -1 }
    if #opts > 0 then
        cmd[5] = table.concat(opts, ',')
    end
    mp.command_native(cmd)
    -- 从脚本加载文件时统一强制设置标题（URL 与本地文件一致），保证菜单标题与记录标题一致；
    -- force-media-title 是持久属性，须在 end-file 时清理，避免残留污染非脚本加载的文件
    if params.media_title and params.media_title ~= '' then
        mp.set_property('force-media-title', params.media_title)
        force_title_set = true
    end
    if params.audio_path then
        mp.set_property('audio-files', params.audio_path)
    end
end


--- 本次播放已开始：消费脚本预设的强制标题（无论是否启用记录都要消费）
mp.register_event('file-loaded', function()
    force_title_set = false
end)

return M
