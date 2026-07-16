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

--- 注入依赖
function M.init(cfg, i18n, st, hist, ut)
    config = cfg
    I18N = i18n
    storage = st
    history = hist
    utils = ut
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
    new_entry.progress = utils.format_time(mp.get_property_number('duration', 0))

    if utils.is_url(new_entry.path) then
        M._handle_url()
        loaded = true
        return
    end

    M._handle_local_file()
    loaded = true
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
            new_entry.progress = I18N.live
            mp.unobserve_property(ob_duration)
        end
        twice = true
        mp.add_timeout(3, function() mp.unobserve_property(ob_duration) end)
    end
    mp.observe_property('duration', 'number', ob_duration)
end

--- 处理本地文件条目
function M._handle_local_file()
    new_entry.upper_path, new_entry.folder = utils.get_folder_info(new_entry.path, utils_mod)

    if not loaded and not from_record and config.resume_in_folder then
        M._check_resume_in_folder()
    end

    new_entry.pos_in_folder = utils.get_pos_in_folder(new_entry.path, utils_mod, mp.get_property_native('platform'))
end

--- 检查同文件夹是否有其他视频可续播
function M._check_resume_in_folder()
    local all_view = history.get_view('all')
    local folders_view = history.get_view('by_folder')

    for _, f in ipairs(folders_view) do
        local peer = f.value.peers[1]
        local raw_entries = history.get_entries()
        local entry = raw_entries[peer]

        if new_entry.upper_path == entry.upper_path and new_entry.path ~= entry.path then
            local menu_props = {
                title = I18N.resume_in_folder,
                selected_index = 1,
                items = {
                    {
                        title = entry.media_title,
                        hint = entry.progress,
                        active = true,
                        icon = 'history',
                        value = { path = entry.path, pos = entry.pos },
                    },
                    {
                        title = new_entry.media_title,
                        hint = I18N.now,
                        muted = true,
                        selectable = false,
                        icon = '',
                    },
                },
                callback = { script_name, 'history_menu_event' },
            }
            mp.commandv('script-message-to', 'uosc', 'open-menu', utils_mod.format_json(menu_props))

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
            break
        end
    end
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
    from_record = false
end

--- on_unload 钩子：捕获最终播放位置
function M.on_unload(hook)
    if not new_entry then new_entry = {} end
    if not next(new_entry) then return end

    hook:defer()
    local pos = mp.get_property_number('time-pos', 0)
    hook:cont()

    if pos >= 3 then
        new_entry.pos = pos - 3
    else
        new_entry.pos = 0
    end

    if new_entry.progress then
        new_entry.progress = utils.format_time(pos) .. ' / ' .. new_entry.progress
    end
end

--- 清空新条目（禁用记录时）
function M.clear_new_entry()
    new_entry = {}
end

--- 加载文件辅助函数
function M.load_file(params)
    from_record = true
    local opts = string.format('start=%d', params.pos or 0)
    if params.url then
        opts = string.format('%s,force-media-title="%s"', opts, params.media_title or '')
    end
    if params.audio_path then
        opts = string.format('%s,audio-files="%s"', opts, params.audio_path)
    end
    mp.commandv('loadfile', params.path, 'replace', -1, opts)
end

return M
