-- 历史菜单：打开/更新/搜索 + 事件路由

local M = {}

local mp
local utils      -- mp.utils
local script_name
local I18N          -- i18n
local config
local history    -- 历史数据模块
local builder    -- 菜单构造器

-- 由 main.lua 注入
M.global_actions = nil
M.global_utils = nil

function M.init(params)
    mp = params.mp
    utils = params.utils
    script_name = params.script_name
    I18N = params.i18n
    config = params.config
    history = params.history
    builder = params.builder
end

-----------------------------------------------------------------------------
-- 菜单打开/更新 ------------------------------------------------------------
-----------------------------------------------------------------------------

function M.open(filter, select_index)
    local items = history.get_view(filter)
    local title, id

    if filter == 'all' then
        title = I18N.title_all .. ' (' .. tostring(#items) .. ')'
        id = 'all'
    elseif filter == 'by_folder' then
        title = I18N.title_folders .. ' (' .. tostring(#items) .. ')'
        id = 'by_folder'
    else
        title = I18N.title_dedup .. ' (' .. tostring(#items) .. ')'
        id = 'recent'
    end

    local menu_props = {
        type = 'history',
        id = id,
        title = title,
        selected_index = select_index or 1,
        items = items,
        item_actions = {
            { name = 'mark', icon = 'star', label = I18N.bookmark_add },
            { name = 'delete', icon = 'delete', label = I18N.del },
        },
        footnote = I18N.footnote,
        callback = { script_name, 'history_menu_event' },
    }

    if config.search_sorting then
        menu_props.on_search = 'callback'
        menu_props.search_debounce = 'submit'
    end

    mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json(menu_props))
end

function M.update(filter, select_index)
    local items = history.get_view(filter)
    local title, id

    if filter == 'all' then
        title = I18N.title_all .. ' (' .. tostring(#items) .. ')'
        id = 'all'
    elseif filter == 'by_folder' then
        title = I18N.title_folders .. ' (' .. tostring(#items) .. ')'
        id = 'by_folder'
    else
        title = I18N.title_dedup .. ' (' .. tostring(#items) .. ')'
        id = 'recent'
    end

    local menu_props = {
        type = 'history',
        id = id,
        title = title,
        selected_index = select_index or 1,
        items = items,
        item_actions = {
            { name = 'mark', icon = 'star', label = I18N.bookmark_add },
            { name = 'delete', icon = 'delete', label = I18N.del },
        },
        footnote = I18N.footnote,
        callback = { script_name, 'history_menu_event' },
    }

    if config.search_sorting then
        menu_props.on_search = 'callback'
        menu_props.search_debounce = 'submit'
    end

    mp.commandv('script-message-to', 'uosc', 'update-menu', utils.format_json(menu_props))
end

--- 打开搜索结果菜单
function M.open_search(results, select_index, filter)
    filter = filter or history.get_filter()
    local prefix
    if filter == 'all' then prefix = I18N.title_all
    elseif filter == 'by_folder' then prefix = I18N.title_folders
    else prefix = I18N.title_dedup end

    local menu_props = {
        type = 'history',
        id = 'search_menu',
        title = string.format('%s - %s(%d)', prefix, I18N.search_results, #results),
        items = results,
        selected_index = select_index or 0,
        item_actions = {{ name = 'mark', icon = 'star', label = I18N.bookmark_add }},
        on_search = 'callback',
        search_debounce = 'submit',
        callback = { script_name, 'history_menu_event' },
    }

    local current_id = mp.get_property_native('user-data/uosc/menu/id')
    if current_id == menu_props.id then
        mp.commandv('script-message-to', 'uosc', 'update-menu', utils.format_json(menu_props))
    else
        mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json(menu_props))
    end
end

--- 切换历史菜单（打开/关闭）
function M.toggle()
    if mp.get_property_native('user-data/uosc/menu/type') ~= 'history' then
        M.open(history.get_filter(), 1)
    else
        mp.commandv('script-message-to', 'uosc', 'close-menu')
    end
end

-----------------------------------------------------------------------------
-- 事件路由 -----------------------------------------------------------------
-----------------------------------------------------------------------------

-- 跨调用临时状态
local pending = {
    mark_source = nil,
    mark_filter = nil,
    mark_index = nil,
    search_results = nil,
}

function M.set_mark_return(source, filter, index, search_results)
    pending.mark_source = source
    pending.mark_filter = filter
    pending.mark_index = index
    pending.search_results = search_results
end

--- 事件路由表
M.handlers = {}

function M.handlers.activate(event)
    local action = event.action
    if action == 'delete' then
        M._handle_delete(event)
    elseif action == 'mark' then
        M._handle_mark(event)
    else
        local value = event.value
        if not value then return end
        local load_values = M._get_load_values(event, value)
        if M.global_actions then M.global_actions.load_file(load_values) end
        mp.commandv('script-message-to', 'uosc', 'close-menu')
    end
end

function M.handlers.key(event)
    local key = event.key
    if key == 'del' then
        local peers = event.selected_item and event.selected_item.value and event.selected_item.value.peers
        local index = event.selected_item and event.selected_item.index or event.index
        if not peers or history.get_filter() == 'all' then
            local all_view = history.get_view('all')
            if all_view and index and all_view[index] and all_view[index].value and all_view[index].value.peers then
                peers = all_view[index].value.peers
            end
        end
        if peers then history.remove_indices(peers)
        else history.remove_at(index) end
        history.invalidate_cache()
        M.update(history.get_filter(), index)
    elseif key == 'left' or key == 'right' then
        -- 循环切换过滤模式
        local cur = history.get_filter()
        if key == 'right' then
            if cur == 'all' then cur = 'recent' elseif cur == 'recent' then cur = 'by_folder' elseif cur == 'by_folder' then cur = 'all' end
        else
            if cur == 'all' then cur = 'by_folder' elseif cur == 'recent' then cur = 'all' elseif cur == 'by_folder' then cur = 'recent' end
        end
        history.set_filter(cur)
        M.update(cur, 1)
    end
end

function M.handlers.search(event)
    local items = history.get_view()
    local results = {}
    local kw = M.global_utils
    for _, v in ipairs(items) do
        if kw and kw.keywords_match(event.query, v.title) then table.insert(results, v) end
    end
    if #results > 0 then
        pending.search_results = results
        M.open_search(results, 0)
    end
end

-----------------------------------------------------------------------------
-- 内部处理函数 -------------------------------------------------------------
-----------------------------------------------------------------------------

function M._get_load_values(event, value)
    if value.path then
        local raw_entries = history.get_entries()
        local entry = raw_entries[event.index]
        local values = { path = value.path, pos = value.pos }
        if value.url then
            values.url = true
            values.audio_path = value.audio_path
            values.media_title = value.media_title
        elseif entry then
            values.url = entry.url
            values.audio_path = entry.audio_path
            values.media_title = entry.media_title
        end
        return values
    end
    return value
end

function M._handle_delete(event)
    local peers = event.value and event.value.peers
    local index = event.selected_item and event.selected_item.index or event.index
    if not peers or history.get_filter() == 'all' then
        local all_view = history.get_view('all')
        if all_view and index and all_view[index] and all_view[index].value and all_view[index].value.peers then
            peers = all_view[index].value.peers
        end
    end
    if peers then history.remove_indices(peers) else history.remove_at(index) end
    history.invalidate_cache()
    M.update(history.get_filter(), index)
end

function M._handle_mark(event)
    local raw_entries = history.get_entries()
    local is_search = (event.menu_id == 'search_menu')
    local title = ''
    local value_path = ''

    if is_search and pending.search_results then
        title = pending.search_results[event.index] and pending.search_results[event.index].title or ''
        value_path = event.value and event.value.path or ''
    else
        if history.get_filter() == 'all' then
            if config.use_filename and raw_entries[event.index] and not history.is_url_entry(raw_entries[event.index]) then
                _, title = utils.split_path(raw_entries[event.index].path)
            else
                title = raw_entries[event.index] and raw_entries[event.index].media_title or ''
            end
            value_path = raw_entries[event.index] and raw_entries[event.index].path or ''
        else
            local peers = event.value and event.value.peers
            local raw_idx = peers and peers[1]
            if raw_idx then
                if config.use_filename and not history.is_url_entry(raw_entries[raw_idx]) then
                    _, title = utils.split_path(raw_entries[raw_idx].path)
                else
                    title = raw_entries[raw_idx].media_title or ''
                end
                value_path = raw_entries[raw_idx].path or ''
            end
        end
    end

    M.set_mark_return(is_search and 'search' or 'menu', history.get_filter(), event.index, pending.search_results)
    if M.global_actions then M.global_actions.add_bookmark({ title = title, value = value_path }) end
    if M.global_bookmark_menu then M.global_bookmark_menu.set_mark_return_pending() end
end

--- 添加书签后返回历史菜单
function M.return_after_mark()
    if pending.mark_source == 'search' and pending.search_results then
        M.open_search(pending.search_results, pending.mark_index)
    elseif pending.mark_source == 'menu' then
        M.open(pending.mark_filter, pending.mark_index)
    end
    M.clear_pending()
end

function M.clear_pending()
    pending = { mark_source = nil, mark_filter = nil, mark_index = nil, search_results = nil }
end

-----------------------------------------------------------------------------
-- 事件分发器 ---------------------------------------------------------------
-----------------------------------------------------------------------------

function M.handle_event(json)
    local event = utils.parse_json(json)
    if not event or not event.type then return end
    local handler = M.handlers[event.type]
    if type(handler) == 'function' then handler(event) end
end

return M
