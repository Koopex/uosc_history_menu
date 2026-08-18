-- 历史菜单：打开/更新/搜索 + 事件路由

local M = {}

local mp
local utils      -- mp.utils
local script_name
local I18N          -- i18n
local config
local history    -- 历史数据模块
local builder    -- 菜单构造器
local clipboard  -- 剪贴板
local our_utils  -- 本地纯函数工具（lib/utils.lua）

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
    clipboard = params.clipboard
    our_utils = params.our_utils
end

-----------------------------------------------------------------------------
-- 菜单打开/更新 ------------------------------------------------------------
-----------------------------------------------------------------------------

--- 根据配置的操作按钮列表构建 uosc 按钮（顺序即显示顺序）
--- label 附加条目路径：悬停按钮时 uosc 在底部 footnote 显示"按钮名 + 换行 + 完整路径"
--- 按钮定义在调用时构造，避免模块加载期引用尚未注入的 I18N
local function build_actions(list, path)
    local defs = {
        mark   = { icon = 'star', label = I18N.bookmark_add },
        copy   = { icon = 'content_copy', label = I18N.copy },
        delete = { icon = 'delete', label = I18N.del },
    }
    local actions = {}
    for _, name in ipairs(list or {}) do
        local def = defs[name]
        if def then
            actions[#actions + 1] = {
                name = name,
                icon = def.icon,
                label = our_utils and our_utils.footnote_label(def.label, path) or def.label,
            }
        end
    end
    return actions
end

--- 递归为叶子条目附加带路径说明的操作按钮；
--- 子菜单节点补充回调/footnote（uosc 会把子菜单节点上的这些字段继承到打开的下一级菜单）
local function attach_item_actions(list)
    for _, it in ipairs(list) do
        if it.items then
            it.callback = { script_name, 'history_menu_event' }
            it.footnote = I18N.footnote
            attach_item_actions(it.items)
        elseif it.value and it.value.path then
            it.actions = build_actions(config.history_actions, it.value.path)
        end
    end
end

--- 构造历史菜单属性（open/update 共用）
local function build_props(filter, select_index)
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

    local item_actions = build_actions(config.history_actions)
    attach_item_actions(items)

    local menu_props = {
        type = 'history',
        id = id,
        title = title,
        selected_index = select_index or 1,
        items = items,
        item_actions = item_actions,
        footnote = I18N.footnote,
        callback = { script_name, 'history_menu_event' },
    }

    if config.search_sorting then
        menu_props.on_search = 'callback'
        menu_props.search_debounce = 'submit'
    end
    -- 允许用 ctrl+d 收藏当前选中的条目/分组（来源分组视图的文件夹节点没有操作按钮，需要按键触发）
    menu_props.bind_keys = { 'ctrl+d' }

    return menu_props
end

function M.open(filter, select_index, submenu_id)
    if submenu_id then
        mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json(build_props(filter, select_index)), submenu_id)
        if select_index then
            mp.commandv('script-message-to', 'uosc', 'select-menu-item', 'history', tostring(select_index), submenu_id)
        end
    else
        mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json(build_props(filter, select_index)))
    end
end

function M.update(filter, select_index, submenu_id)
    if submenu_id then
        mp.commandv('script-message-to', 'uosc', 'update-menu', utils.format_json(build_props(filter, select_index)), submenu_id)
    else
        mp.commandv('script-message-to', 'uosc', 'update-menu', utils.format_json(build_props(filter, select_index)))
    end
end

--- 是否为“按来源分组”视图的子菜单 id（一级为 by_folder，子菜单为 by_folder.*）
function M._is_source_submenu(menu_id)
    return menu_id ~= nil and menu_id ~= 'by_folder' and menu_id:sub(1, 10) == 'by_folder.'
end


--- 构建搜索菜单属性
local function build_search_props(results, select_index, filter)
    filter = filter or history.get_filter()
    local prefix
    if filter == 'all' then prefix = I18N.title_all
    elseif filter == 'by_folder' then prefix = I18N.title_folders
    else prefix = I18N.title_dedup end

    attach_item_actions(results)

    return {
        type = 'history',
        id = 'search_menu',
        title = string.format('%s - %s(%d)', prefix, I18N.search_results, #results),
        items = results,
        selected_index = select_index or 0,
        item_actions = build_actions(config.history_actions),
        on_search = 'callback',
        search_debounce = 'submit',
        callback = { script_name, 'history_menu_event' },
    }
end

--- 打开搜索结果菜单
function M.open_search(results, select_index, filter)
    local menu_props = build_search_props(results, select_index, filter)
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
    search_query = nil,
    mark_menu_id = nil,
}

function M.set_mark_return(source, filter, index, search_results, menu_id)
    pending.mark_source = source
    pending.mark_filter = filter
    pending.mark_index = index
    pending.search_results = search_results
    pending.mark_menu_id = menu_id
end

--- 事件路由表
M.handlers = {}

function M.handlers.activate(event)
    local action = event.action
    if action == 'delete' then
        M._handle_delete(event)
    elseif action == 'mark' then
        M._handle_mark(event)
    elseif action == 'copy' then
        M._handle_copy(event)
    else
        local value = event.value
        if not value then return end
        local load_values = M._get_load_values(event, value)
        if M.global_actions then M.global_actions.load_file(load_values) end
        mp.commandv('script-message-to', 'uosc', 'close-menu')
    end
end

function M.handlers.key(event)
    local key = event.id
    if key == 'del' then
        M._handle_delete(event)
    elseif key == 'left' or key == 'right' then
        -- 线性切换过滤模式：全部 <-> 去重 <-> 按来源分组（两端不循环）
        local cur = history.get_filter()
        local next_filter
        if key == 'right' then
            if cur == 'all' then next_filter = 'recent'
            elseif cur == 'recent' then next_filter = 'by_folder' end
        else
            if cur == 'by_folder' then next_filter = 'recent'
            elseif cur == 'recent' then next_filter = 'all' end
        end
        if next_filter and next_filter ~= cur then
            history.set_filter(next_filter)
            M.update(next_filter, 1)
        end
    elseif event.id == 'ctrl+c' then
        M._handle_copy(event)
    elseif key == 'ctrl+d' then
        M._handle_mark(event)
    end
end

function M.handlers.search(event)
    -- 来源分组视图为嵌套结构，搜索时改用去重表条目（叶子与分组视图一致）
    local filter = history.get_filter()
    local items = (filter == 'by_folder') and history.get_view('recent') or history.get_view()
    local results = {}
    local kw = M.global_utils
    for _, v in ipairs(items) do
        if kw and kw.keywords_match(event.query, v.title) then table.insert(results, v) end
    end
    if #results > 0 then
        pending.search_query = event.query
        pending.search_results = results
        M.open_search(results, 0)
    end
end

-----------------------------------------------------------------------------
-- 内部处理函数 -------------------------------------------------------------
-----------------------------------------------------------------------------

function M._get_load_values(event, value)
    if value.path then
        -- 已播进度超过阈值百分比则从头播放，否则恢复进度
        local pos = (M.global_utils and M.global_utils.apply_restart_threshold(value.pos, value.duration, config.restart_threshold))
            or value.pos or 0
        -- 元数据直接取自视图 value，避免用视图索引回查原始数组导致错位
        return {
            path = value.path,
            pos = pos,
            url = value.url,
            audio_path = value.audio_path,
            media_title = value.media_title,
            auto_next = value.auto_next,
        }
    end
    return value
end

--- 去掉菜单标题前的图标前缀（📁/🎬/🔗 + 两个空格）
local function strip_icon_prefix(title)
    if not title then return '' end
    for _, prefix in ipairs({ '📁  ', '🎬  ', '🔗  ' }) do
        if title:sub(1, #prefix) == prefix then
            return title:sub(#prefix + 1)
        end
    end
    return title
end

--- 叶子条目标题（优先文件名或媒体标题）
local function leaf_title(value)
    if not value then return '' end
    if config.use_filename and not value.url then
        local _, file_name = utils.split_path(value.path)
        return file_name
    end
    return value.media_title or I18N.unknown
end

--- 将来源分组视图节点递归转换为收藏夹格式节点 {title, items|path}
local function build_bookmark_node(node)
    if node.items then
        local items = {}
        for _, child in ipairs(node.items) do
            table.insert(items, build_bookmark_node(child))
        end
        return { title = strip_icon_prefix(node.title), items = items }
    end
    local v = node.value
    return { title = v and leaf_title(v) or '', path = v and v.path }
end

--- 递归收集分组节点下所有叶子的原始索引（peers）
local function collect_node_peers(node, out)
    if node.items then
        for _, child in ipairs(node.items) do collect_node_peers(child, out) end
    elseif node.value and node.value.peers then
        for _, p in ipairs(node.value.peers) do out[#out + 1] = p end
    end
end

--- 在视图树中按 id 查找节点（来源分组视图的子菜单 id 即节点 id）
local function find_node_by_id(list, menu_id)
    for _, node in ipairs(list) do
        if node.id == menu_id then return node end
        if node.items then
            local found = find_node_by_id(node.items, menu_id)
            if found then return found end
        end
    end
    return nil
end

--- 按菜单 id + 索引解析当前选中的视图节点（来源分组子菜单需先按 id 下钻）
function M._resolve_view_node(filter, menu_id, index)
    if not index then return nil end
    local items = history.get_view(filter)
    if not menu_id or menu_id == filter then
        return items[index]
    end
    if filter == 'by_folder' then
        local parent = find_node_by_id(items, menu_id)
        return parent and parent.items and parent.items[index]
    end
    return nil
end

--- 解析事件对应的菜单节点：叶子优先用事件携带的 value（含 peers，避免搜索后下标错位），
--- 分组节点/子菜单再按菜单 id + 索引回查视图
function M._resolve_event_node(event)
    local index = event.selected_item and event.selected_item.index or event.index
    -- 叶子条目：事件 value 自带 path/peers，原生搜索与自定义搜索过滤后依然有效
    local v = event.selected_item and event.selected_item.value or event.value
    if v and (v.peers or v.path) then
        return { value = v }
    end
    -- 自定义搜索菜单：从结果列表按索引解析
    if event.menu_id == 'search_menu' then
        local item = pending.search_results and pending.search_results[index]
        return item
    end
    -- 分组节点/来源分组子菜单：按视图解析
    return M._resolve_view_node(history.get_filter(), event.menu_id, index)
end

--- 复制历史条目为收藏夹格式：叶子 {title, path}；来源分组文件夹递归为 {title, items}
function M._handle_copy(event)
    local node = M._resolve_event_node(event)
    if not node then return end
    if node.items then
        -- 来源分组视图的文件夹/Season 节点：连同子项一起复制
        if not (clipboard and clipboard.set(utils.format_json(build_bookmark_node(node)))) then
            mp.osd_message(I18N.clipboard_error)
            return
        end
        mp.osd_message(I18N.copied)
        return
    end
    local v = node.value
    if not v or not v.path then return end
    local text = utils.format_json({ title = leaf_title(v), path = v.path })
    if not (clipboard and clipboard.set(text)) then
        mp.osd_message(I18N.clipboard_error)
        return
    end
    mp.osd_message(I18N.copied)
end

--- 删除搜索结果后刷新：用新数据重跑关键词过滤，原地 update-menu 刷新结果菜单
function M._refresh_search(keep_index)
    if not pending.search_query then return end
    local filter = history.get_filter()
    local items = (filter == 'by_folder') and history.get_view('recent') or history.get_view()
    local results = {}
    local kw = M.global_utils
    for _, v in ipairs(items) do
        if kw and kw.keywords_match(pending.search_query, v.title) then table.insert(results, v) end
    end
    pending.search_results = results
    local select_index = keep_index and math.min(keep_index, #results) or 1
    mp.commandv('script-message-to', 'uosc', 'update-menu',
        utils.format_json(build_search_props(results, select_index, filter)))
end

function M._handle_delete(event)
    local index = event.selected_item and event.selected_item.index or event.index
    local filter = history.get_filter()
    local node = M._resolve_event_node(event)
    if not node then return end
    if node.items then
        -- 分组节点：删除该分组下所有记录
        local peers = {}
        collect_node_peers(node, peers)
        history.remove_indices(peers)
    elseif node.value and node.value.peers then
        history.remove_indices(node.value.peers)
    else
        return
    end
    history.invalidate_cache()
    if event.menu_id == 'search_menu' then
        -- 自定义搜索：用新数据重跑过滤，原地刷新结果菜单
        M._refresh_search(index)
    else
        -- 原生搜索/普通视图：uosc update 后保留搜索词并自动重过滤
        local submenu_id = M._is_source_submenu(event.menu_id) and event.menu_id or nil
        M.update(filter, index, submenu_id)
    end
end

function M._handle_mark(event)
    local is_search = (event.menu_id == 'search_menu')
    local index = event.selected_item and event.selected_item.index or event.index
    local filter = history.get_filter()

    -- 解析当前选中的节点：统一走事件节点解析（搜索/原生搜索/视图）
    local node = M._resolve_event_node(event)
    if not node then return end

    if node.items then
        -- 来源分组视图的文件夹/Season 节点：连同子项一起收藏
        local bm_node = build_bookmark_node(node)
        M.set_mark_return('menu', filter, index, nil, event.menu_id)
        if M.global_bookmark_menu then M.global_bookmark_menu.set_mark_return_pending() end
        if M.global_actions then M.global_actions.add_bookmark_node(bm_node) end
        return
    end

    local v = node.value
    local value_path = v and v.path or ''
    local title = leaf_title(v)
    M.set_mark_return(is_search and 'search' or 'menu', filter, index, pending.search_results,
        is_search and nil or event.menu_id)
    -- 先登记"添加完成后返回历史菜单"标记，再触发添加（快速收藏为同步插入，需要此标记生效）
    if M.global_bookmark_menu then M.global_bookmark_menu.set_mark_return_pending() end
    if M.global_actions then M.global_actions.add_bookmark({ title = title, path = value_path }) end
end

--- 添加书签后返回历史菜单
function M.return_after_mark()
    if pending.mark_source == 'search' and pending.search_results then
        M.open_search(pending.search_results, pending.mark_index)
    elseif pending.mark_source == 'menu' then
        local menu_id = pending.mark_menu_id
        if M._is_source_submenu(menu_id) then
            M.open(pending.mark_filter, pending.mark_index, menu_id)
        else
            M.open(pending.mark_filter, pending.mark_index)
        end
    end
    M.clear_pending()
end

function M.clear_pending()
    pending = { mark_source = nil, mark_filter = nil, mark_index = nil, search_results = nil, mark_menu_id = nil }
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
