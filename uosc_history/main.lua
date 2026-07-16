-- uosc_history_menu - 入口文件
-- 加载所有模块并注册 mpv 绑定

local mp = require('mp')
local mp_utils = require('mp.utils')

local script_name = mp.get_script_name()
local script_dir = mp.get_script_directory()


-----------------------------------------------------------------------------
-- 辅助函数 -----------------------------------------------------------------
-----------------------------------------------------------------------------

local function merge(a, b)
    local r = {}
    for k, v in pairs(a) do r[k] = v end
    for k, v in pairs(b) do r[k] = v end
    return r
end

-----------------------------------------------------------------------------
-- 加载模块 -----------------------------------------------------------------
-----------------------------------------------------------------------------

local function safe_dofile(path)
    local ok, result = pcall(dofile, path)
    if not ok then
        mp.msg.error('module load failed: ' .. path .. ' -- ' .. tostring(result))
        return nil
    end
    return result
end

local config_mod = safe_dofile(script_dir .. '/config.lua')
local utils = safe_dofile(script_dir .. '/utils.lua')

if not config_mod or not utils then
    mp.msg.error('module load failed, aborting')
    return
end

-- 读取并展开配置
local config = config_mod.read(script_name)
config.log_path = config_mod.expand_log_path(config.log_path)

-- 初始化运行时选项默认值
config.log = true
config.filter = 'dedup'
config.quick_mark = false

-- 加载 i18n（回退到 en）
local lang = config.language or 'en'
local I18N = safe_dofile(script_dir .. '/i18n/' .. lang .. '.lua')
if not I18N then
    I18N = safe_dofile(script_dir .. '/i18n/en.lua')
end
if not I18N then
    mp.msg.error('i18n load failed, aborting')
    return
end

-- 加载数据模块
local storage = safe_dofile(script_dir .. '/storage.lua')
local history = safe_dofile(script_dir .. '/history.lua')
local bookmarks = safe_dofile(script_dir .. '/bookmarks.lua')

-- 加载菜单模块
local builder = safe_dofile(script_dir .. '/menus/builder.lua')
local history_menu = safe_dofile(script_dir .. '/menus/history_menu.lua')
local bookmark_menu = safe_dofile(script_dir .. '/menus/bookmark_menu.lua')

-- 加载追踪器
local tracker = safe_dofile(script_dir .. '/tracker.lua')

if not storage or not history or not bookmarks or not builder
    or not history_menu or not bookmark_menu or not tracker then
    mp.msg.error('module load failed, aborting')
    return
end


-----------------------------------------------------------------------------
-- 初始化模块 ---------------------------------------------------------------
-----------------------------------------------------------------------------

local shared_params = {
    mp = mp,
    utils = mp_utils,
    script_name = script_name,
    i18n = I18N,
    config = config,
}

history.init({}, {log = true, filter = 'dedup', quick_mark = false, filename = config.filename})
bookmarks.init({})

builder.init(script_name)

history_menu.init(merge(shared_params, {
    history = history,
    builder = builder,
}))

bookmark_menu.init(merge(shared_params, {
    bookmarks = bookmarks,
    builder = builder,
    history_menu = history_menu,
}))

tracker.init(config, I18N, storage, history, utils)

-----------------------------------------------------------------------------
-- 跨模块桥接 ---------------------------------------------------------------
-----------------------------------------------------------------------------

local actions = {}

function actions.load_file(params)
    tracker.set_from_record(true)
    tracker.load_file(params)
end

function actions.add_bookmark(bm)
    if config.quick_mark then
        bookmark_menu.start_add_bookmark(bm.title, bm.value, true)
    else
        bookmark_menu.set_pending_bookmark(bm)
        bookmark_menu.open_folder_selector()
    end
end

history_menu.global_actions = actions
history_menu.global_utils = utils
history_menu.global_bookmark_menu = bookmark_menu
bookmark_menu.global_actions = actions

-----------------------------------------------------------------------------
-- 加载已保存数据 -----------------------------------------------------------
-----------------------------------------------------------------------------

local data_loaded = false

local function load_data()
    if data_loaded then return end; data_loaded = true
    local data = storage.load(config.log_path)
    if data then
        local opts = data.options or {}
        if opts.filter == nil then opts.filter = 'dedup' end
        if opts.log == nil then opts.log = true end
        if opts.quick_mark == nil then opts.quick_mark = false end

        history.init(data.entries or {}, opts)
        bookmarks.init(data.bookmark_entries or {})

        if opts.log ~= nil then config.log = opts.log end
        if opts.filter ~= nil then config.filter = opts.filter end
        if opts.quick_mark ~= nil then config.quick_mark = opts.quick_mark end
        mp.msg.info(opts.log and I18N.log_enabled or I18N.log_disabled)
    end
end

-----------------------------------------------------------------------------
-- 操作处理函数 -------------------------------------------------------------
-----------------------------------------------------------------------------

local function toggle_history()
    history_menu.toggle()
end

local function toggle_bookmarks()
    bookmark_menu.toggle()
end

local function enable_history()
    if config.log then
        mp.osd_message(I18N.log_disabled)
        mp.msg.info(I18N.log_disabled)
        config.log = false
        tracker.clear_new_entry()
    else
        mp.osd_message(I18N.log_enabled)
        mp.msg.info(I18N.log_enabled)
        config.log = true
        tracker.capture_current()
    end
end

local function clear_history()
    local menu_props = builder.confirm_dialog(
        I18N.clear_history,
        I18N.yes,
        I18N.no,
        {script_name, 'clear_confirmed_history'}
    )
    mp.commandv('script-message-to', 'uosc', 'open-menu', mp_utils.format_json(menu_props))
end

local function clear_bookmarks()
    local menu_props = builder.confirm_dialog(
        I18N.clear_bookmarks,
        I18N.yes,
        I18N.no,
        {script_name, 'clear_confirmed_bookmarks'}
    )
    mp.commandv('script-message-to', 'uosc', 'open-menu', mp_utils.format_json(menu_props))
end

local function add_bookmarks()
    if mp.get_property_bool('idle-active', 'false') then return end

    local new_entry = tracker.get_new_entry()
    local title, path

    if new_entry and next(new_entry) then
        path = new_entry.path
        if config.filename and not new_entry.url then
            _, title = mp_utils.split_path(path)
        else
            title = new_entry.media_title
        end
    else
        path = mp.get_property('path', '')
        if config.filename then
            title = mp.get_property('filename', '')
        else
            title = mp.get_property('media-title', '')
        end
    end

    bookmark_menu.set_pending_bookmark({title = title, value = path})
    if config.quick_mark then
        bookmark_menu.start_add_bookmark(title, path, true)
    else
        bookmark_menu.open_folder_selector()
    end
end

local function toggle_quick_mark()
    config.quick_mark = not config.quick_mark
    mp.osd_message(config.quick_mark and I18N.quick_mark_enable or I18N.quick_mark_disable)
end

-----------------------------------------------------------------------------
-- 确认回调 -----------------------------------------------------------------
-----------------------------------------------------------------------------

local function clear_confirmed_history(json)
    mp.commandv("script-message-to", "uosc", "close-menu")
    local ok, event = pcall(mp_utils.parse_json, json)
    if not ok then return end
    if event and event.value == "yes" then
        history.clear()
        mp.osd_message(I18N.cleared)
    end
end

local function clear_confirmed_bookmarks(json)
    mp.commandv("script-message-to", "uosc", "close-menu")
    local ok, event = pcall(mp_utils.parse_json, json)
    if not ok then return end
    if event and event.value == "yes" then
        bookmarks.clear()
        mp.osd_message(I18N.cleared)
    end
end

-----------------------------------------------------------------------------
-- 文件生命周期 -------------------------------------------------------------
-----------------------------------------------------------------------------

local resume_state = {resumable = false}

local function resume()
    mp.unobserve_property(observe_pause)
    local entries = history.get_entries()
    if #entries > 0 then
        mp.commandv('script-message-to', 'uosc', 'close-menu')
        local e = entries[1]
        tracker.load_file({
            path = e.path,
            pos = e.pos,
            url = e.url,
            audio_path = e.audio_path,
            media_title = e.media_title,
        })
        mp.set_property('pause', 'no')
    end
end

local function observe_pause(_, pause)
    if resume_state.resumable then
        resume()
    end
    resume_state.resumable = true
end

local function on_file_loaded()
    load_data()
    if config.log then
        tracker.on_file_loaded()
    end
    mp.unobserve_property(observe_pause)
end

local function on_end_file(event)
    tracker.on_end_file()
    resume_state.resumable = false
    if event.reason ~= 'error' then
        mp.observe_property('pause', 'bool', observe_pause)
    end
end

local function on_unload(hook)
    tracker.on_unload(hook)
end

local function on_shutdown()
    local data = {
        options = {
            log = config.log,
            filter = history.get_filter(),
            quick_mark = config.quick_mark,
        },
        entries = history.get_entries(),
        bookmark_entries = bookmarks.get_entries(),
    }
    storage.save(config.log_path, data)
end

-----------------------------------------------------------------------------
-- 启动 ---------------------------------------------------------------------
-----------------------------------------------------------------------------

local buttons = {
    {
        name = 'history',
        value = {
            icon = 'history',
            tooltip = I18N.tooltip,
            command = 'script-binding ' .. script_name .. '/history',
        },
    },
    {
        name = 'bookmarks',
        value = {
            icon = 'folder_special',
            tooltip = I18N.title_bookmarks,
            command = 'script-binding ' .. script_name .. '/bookmarks',
        },
    },
    {
        name = 'add_bookmarks',
        value = {
            icon = 'star',
            tooltip = I18N.bookmark_add,
            command = 'script-binding ' .. script_name .. '/add_bookmarks',
        },
    },
}

local function startup()
    for _, b in ipairs(buttons) do
        mp.commandv('script-message-to', 'uosc', 'set-button', b.name, mp_utils.format_json(b.value))
    end

    load_data()
    if mp.get_property_bool('idle-active', 'false') then
        mp.observe_property('pause', 'bool', observe_pause)
        if config.start_action == 'menu' then
            toggle_history()
        elseif config.start_action == 'resume' then
            resume()
        end
    end
end

-----------------------------------------------------------------------------
-- 注册绑定 -----------------------------------------------------------------
-----------------------------------------------------------------------------

mp.add_key_binding(nil, 'history', toggle_history)
mp.add_key_binding(nil, 'enable_history', enable_history)
mp.add_key_binding(nil, 'clear_history', clear_history)
mp.add_key_binding(nil, 'bookmarks', toggle_bookmarks)
mp.add_key_binding(nil, 'add_bookmarks', add_bookmarks)
mp.add_key_binding(nil, 'clear_bookmarks', clear_bookmarks)
mp.add_key_binding(nil, 'toggle_quick_mark', toggle_quick_mark)

mp.register_script_message('clear_confirmed_history', clear_confirmed_history)
mp.register_script_message('clear_confirmed_bookmarks', clear_confirmed_bookmarks)
mp.register_script_message('history_menu_event', function(json) history_menu.handle_event(json) end)
mp.register_script_message('bookmark_menu_event', function(json) bookmark_menu.handle_event(json) end)

mp.add_hook('on_unload', 50, on_unload)
mp.register_event('file-loaded', on_file_loaded)
mp.register_event('end-file', on_end_file)
mp.register_event('shutdown', on_shutdown)

startup()
