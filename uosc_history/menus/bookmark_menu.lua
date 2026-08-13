-- 收藏菜单：打开/更新/分组选择 + 事件路由
-- 操作：F2 重命名、Ctrl+c 复制、Ctrl+x 剪切、Ctrl+v 粘贴、Del 删除、Ctrl+Home/End/PgUp/PgDw/↑/↓ 排序

local M = {}

local mp
local utils
local script_name
local I18N
local bookmarks
local builder
local history_menu
local history
local config
local our_utils
local clipboard

M.global_actions = nil

local pending = {
    pending_bookmark = nil,
    pending_playlist = nil, -- 待收藏的播放列表条目（选择位置后批量插入）
    rename_container = nil, -- 重命名节点的容器路径（数组），{} = 根
    rename_index = nil,
    paste_target = nil,     -- 单 path 导入：{path, container, index}
    pick_create_path = nil, -- 收藏位置浏览器："新建分组"输入框打开时的分组路径
    mark_return_pending = false,
}

-- 脚本内复制/剪切标记：{text, mode='cut'|'copy', source=容器路径, source_index=索引}
-- 粘贴时剪贴板文本一致则视为脚本内操作（移动/复制），否则视为导入
local clip_state = nil

function M.init(params)
    mp = params.mp; utils = params.utils; script_name = params.script_name
    I18N = params.i18n; bookmarks = params.bookmarks; builder = params.builder
    history_menu = params.history_menu
    history = params.history
    config = params.config
    our_utils = params.our_utils
    clipboard = params.clipboard
end

function M.set_pending_bookmark(bm)
    pending.pending_bookmark = bm
    pending.pending_playlist = nil
end

function M.set_mark_return_pending()
    pending.mark_return_pending = true
end

--- 路径列表 ↔ 菜单 id（索引路径，1-based）
local function path_to_id(path_list)
    return 'bookmarks' .. (#path_list > 0 and '.' .. table.concat(path_list, '.') or '')
end

local function id_to_path(menu_id)
    local path = {}
    if menu_id and menu_id ~= 'bookmarks' then
        for p in string.gmatch(menu_id, '(%d+)') do table.insert(path, tonumber(p)) end
    end
    return path
end

--- 收藏位置浏览器菜单 id ↔ 路径（前缀 pick_folder，避免与收藏菜单混淆）
local function pick_id(path_list)
    return 'pick_folder' .. (#path_list > 0 and '.' .. table.concat(path_list, '.') or '')
end

local function pick_id_to_path(menu_id)
    local path = {}
    if menu_id and menu_id:sub(1, 12) == 'pick_folder.' then
        for p in string.gmatch(menu_id:sub(13), '(%d+)') do table.insert(path, tonumber(p)) end
    end
    return path
end

local function selected_index(event)
    return event.selected_item and event.selected_item.index
end

--- 解析事件对应节点的真实索引：优先用条目 value 中构建时写入的 index（搜索过滤后仍正确），回退到事件下标
local function event_index(event)
    local v = event.selected_item and event.selected_item.value or event.value
    if v and type(v) == 'table' and v.index then return v.index end
    return event.selected_item and event.selected_item.index or event.index
end

--- 重建菜单并定位：reopen=true 时用 open-menu（收藏菜单已被对话框替换时）
local function rebuild(container, index, reopen)
    local submenu_id = container and #container > 0 and path_to_id(container) or nil
    M.open(reopen ~= true, submenu_id)
    if index then
        if submenu_id then
            mp.commandv('script-message-to', 'uosc', 'select-menu-item', 'bookmarks', tostring(index), submenu_id)
        else
            mp.commandv('script-message-to', 'uosc', 'select-menu-item', 'bookmarks', tostring(index))
        end
    end
end

--- 数据发生结构性变更后使脚本内剪切标记失效
local function clear_clip_state()
    clip_state = nil
end

function M.open(update, submenu_id)
    local items = bookmarks.get_menu_items(
        { script_name, 'bookmark_menu_event' },
        {
            rename = I18N.rename, copy = I18N.copy, cut = I18N.cut, delete = I18N.delete,
            unknown = I18N.unknown,
            bookmark_footnote = I18N.bookmark_footnote,
        })
    items = M._enrich_items(items)
    if clip_state and clip_state.mode == 'cut' then
        M._apply_cut_marker(items, clip_state.source, clip_state.source_index)
    end
    local props = {
        type = 'bookmarks', id = 'bookmarks', title = I18N.title_bookmarks, items = items,
        on_move = 'callback', on_paste = 'callback', bind_keys = { 'f2', 'ctrl+x' },
        callback = { script_name, 'bookmark_menu_event' },
        footnote = I18N.bookmark_footnote,
    }
    if update then
        if submenu_id then
            mp.commandv('script-message-to', 'uosc', 'update-menu', utils.format_json(props), submenu_id)
        else
            mp.commandv('script-message-to', 'uosc', 'update-menu', utils.format_json(props))
        end
    else
        if submenu_id then
            mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json(props), submenu_id)
        else
            mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json(props))
        end
    end
end

function M.toggle()
    if mp.get_property_native('user-data/uosc/menu/type') ~= 'bookmarks' then
        M.open(false)
    else mp.commandv('script-message-to', 'uosc', 'close-menu') end
end

--- 递归构建收藏位置浏览器菜单树：只列出分组节点，每级顶部为"新建分组/添加到此处"
local function picker_items(container, path_prefix, msg, filter_query, filter_path)
    local items = {
        { title = msg.create, value = { pick_new_folder = true }, align = 'center' },
        { title = msg.add_here, value = { pick_add_here = true }, align = 'center', separator = true },
    }
    local is_filter_level = filter_path and #filter_path == #path_prefix
        and table.concat(filter_path, '.') == table.concat(path_prefix, '.')
    for i, node in ipairs(container) do
        if type(node) == 'table' and node.items ~= nil then
            local node_path = {}
            for _, p in ipairs(path_prefix) do table.insert(node_path, p) end
            table.insert(node_path, i)
            local matched = not is_filter_level or not filter_query or filter_query == ''
                or (node.title or ''):lower():find(filter_query:lower(), 1, true)
            if matched then
                table.insert(items, {
                    id = pick_id(node_path),
                    title = node.title or I18N.unknown,
                    items = picker_items(node.items, node_path, msg, filter_query, filter_path),
                })
            end
        end
    end
    return items
end

--- 收藏位置浏览器：打开（入口保持 open_folder_selector 不变）
function M.open_folder_selector()
    pending.pick_create_path = nil
    M.open_picker(false)
end

--- 打开/更新收藏位置浏览器。submenu_id 用于直接定位到某分组；
--- filter_query/filter_path 用于当前分组内的搜索过滤
function M.open_picker(update, submenu_id, filter_query, filter_path)
    local msg = { create = I18N.create_bookmark_folder, add_here = I18N.add_here }
    local props = {
        type = 'pick_folder',
        id = 'pick_folder',
        title = I18N.select_folder,
        items = picker_items(bookmarks.get_entries(), {}, msg, filter_query, filter_path),
        on_search = 'callback',
        search_debounce = 'submit',
        callback = { script_name, 'bookmark_pick_event' },
    }
    if update then
        if submenu_id then
            mp.commandv('script-message-to', 'uosc', 'update-menu', utils.format_json(props), submenu_id)
        else
            mp.commandv('script-message-to', 'uosc', 'update-menu', utils.format_json(props))
        end
    else
        if submenu_id then
            mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json(props), submenu_id)
        else
            mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json(props))
        end
    end
end

function M.start_add_bookmark(title, value, quick_mark)
    pending.pending_bookmark = { title = title, path = value }
    pending.pending_playlist = nil
    if quick_mark then M._do_insert({ kind = 'quick' }) else M.open_folder_selector() end
end

--- 收藏分组/条目节点（含子项）：快速模式直接插入快速收藏，否则打开位置浏览器
function M.start_add_bookmark_node(node, quick_mark)
    pending.pending_bookmark = node
    pending.pending_playlist = nil
    if quick_mark then M._do_insert({ kind = 'quick' }) else M.open_folder_selector() end
end

--- 收藏当前播放列表（非快速模式）：选择保存位置
function M.start_add_playlist(items)
    pending.pending_bookmark = nil
    pending.pending_playlist = items
    M.open_folder_selector()
end

--- 快速收藏播放列表：在快速收藏分组内新建带时间日期的分组并批量插入
function M.add_playlist_quick(items)
    pending.pending_bookmark = nil
    pending.pending_playlist = nil
    local name = string.format(I18N.playlist_folder_title, os.date('%Y/%m/%d %H:%M'))
    local quick_idx = bookmarks.get_quick_folder_index(I18N.quick_mark_folder)
    local folder_idx = bookmarks.create_folder({quick_idx}, name)
    if not folder_idx then
        mp.osd_message(I18N.clipboard_error)
        return
    end
    local count = 0
    for _, item in ipairs(items) do
        if bookmarks.add_to_folder_path({quick_idx, folder_idx}, item) then count = count + 1 end
    end
    mp.osd_message(I18N.playlist_added:format(count))
end

--- 将待收藏的播放列表条目插入目标分组（target.kind = 'path'）
function M._insert_playlist(target)
    local list = pending.pending_playlist or {}
    pending.pending_playlist = nil
    local target_path = target.path or {}
    local count = 0
    for _, item in ipairs(list) do
        if bookmarks.add_to_folder_path(target_path, item) then count = count + 1 end
    end
    if count == 0 then
        mp.osd_message(I18N.bookmark_exists)
        if pending.mark_return_pending then
            pending.mark_return_pending = false
            if history_menu then history_menu.clear_pending() end
        end
        return
    end
    mp.osd_message(I18N.playlist_added:format(count))
    pending.pending_bookmark = nil
    -- 历史菜单来源返回历史并定位，独立触发则打开收藏菜单定位新分组
    if pending.mark_return_pending then
        pending.mark_return_pending = false
        if history_menu then history_menu.return_after_mark() end
        return
    end
    local target_id = 'bookmarks' .. (#target_path > 0 and '.' .. table.concat(target_path, '.') or '')
    M.open(false, target_id)
    mp.commandv('script-message-to', 'uosc', 'select-menu-item', 'bookmarks', '1', target_id)
end

--- 执行收藏插入。target：{kind='quick'} 快速收藏（不打开任何菜单）；
--- {kind='path', path={...}} 收藏位置浏览器的当前分组
function M._do_insert(target)
    -- 播放列表收藏：一次插入多个条目
    if pending.pending_playlist then
        M._insert_playlist(target)
        return
    end
    if not pending.pending_bookmark then return end
    local bm = pending.pending_bookmark
    local inserted_index, is_duplicate, target_id
    if target.kind == 'quick' then
        local folder_idx, item_idx, status = bookmarks.add_to_quick_folder(bm, I18N.quick_mark_folder)
        inserted_index, is_duplicate = item_idx, (status == 'duplicate')
    elseif target.kind == 'path' then
        inserted_index = bookmarks.add_to_folder_path(target.path or {}, bm)
        is_duplicate = (not inserted_index)
        target_id = 'bookmarks' .. (#target.path > 0 and '.' .. table.concat(target.path, '.') or '')
    else
        return
    end
    if not inserted_index or is_duplicate then
        mp.osd_message(I18N.bookmark_exists)
        if target.kind == 'quick' then
            -- 快速收藏重复：清理标记返回状态，历史菜单保持原位
            if pending.mark_return_pending then
                pending.mark_return_pending = false
                if history_menu then history_menu.clear_pending() end
            end
        end
        return
    end
    mp.osd_message(I18N.added)
    pending.pending_bookmark = nil
    if target.kind == 'quick' then
        -- 快速收藏：不打开任何菜单（历史菜单触发时保持原位）
        if pending.mark_return_pending then
            pending.mark_return_pending = false
            if history_menu then history_menu.clear_pending() end
        end
        return
    end
    -- 非快速收藏：历史菜单来源返回历史并定位，独立触发则打开收藏菜单定位新条目
    if pending.mark_return_pending then
        pending.mark_return_pending = false
        if history_menu then history_menu.return_after_mark() end
    elseif target_id then
        M.open(false, target_id)
        if inserted_index then
            mp.commandv('script-message-to', 'uosc', 'select-menu-item', 'bookmarks', tostring(inserted_index), target_id)
        end
    end
end--- 递归为收藏菜单条目补充历史信息：图标、进度 hint、完整 value（返回新树，不改动缓存）
function M._enrich_items(list)
    local result = {}
    for i, node in ipairs(list) do
        local copy = {}
        for k, v in pairs(node) do copy[k] = v end
        if node.items then
            copy.title = '📁  ' .. (node.title or I18N.unknown)
            copy.items = M._enrich_items(node.items)
            -- 文件夹节点也写入真实索引，供搜索后的按键操作（del/F2 等）正确定位
            copy.value = { index = i }
        elseif node.value then
            if type(node.value) == 'string' then
                local path = node.value
                local item = history and history.get_dedup_by_path(path)
                if item then
                    copy.hint = item.hint
                    -- 浅拷贝历史条目值并写入真实索引（不改动共享缓存；搜索过滤后事件仍能正确定位）
                    copy.value = {}
                    for k, v in pairs(item.value) do copy.value[k] = v end
                    copy.value.index = i
                    local icon = (item.value and item.value.url) and '🔗  ' or '🎬  '
                    copy.title = icon .. (node.title or I18N.unknown)
                else
                    local icon = (our_utils and our_utils.is_url(path)) and '🔗  ' or '🎬  '
                    copy.title = icon .. (node.title or I18N.unknown)
                    copy.value = { path = path, index = i }
                end
            end
        end
        table.insert(result, copy)
    end
    return result
end

--- 将剪切中的节点标记为 muted（视觉反馈，直到粘贴完成或状态失效）
function M._apply_cut_marker(list, path, index)
    local function mark(list, remaining, index)
        if #remaining == 0 then
            if list[index] then list[index].muted = true end
            return
        end
        local node = list[remaining[1]]
        if node and node.items then
            local rest = {}
            for i = 2, #remaining do table.insert(rest, remaining[i]) end
            mark(node.items, rest, index)
        end
    end
    mark(list, path, index)
end

--- 由收藏条目 value 构造加载参数：命中历史时与历史条目一致（套用重播阈值），否则不传 start
function M._load_values(value)
    if type(value) == 'table' and value.path then
        local pos = value.pos
        if pos ~= nil and config and config.restart_threshold ~= nil then
            pos = (our_utils and our_utils.apply_restart_threshold(pos, value.duration, config.restart_threshold)) or 0
        end
        return {
            path = value.path,
            pos = pos,
            url = value.url,
            audio_path = value.audio_path,
            media_title = value.media_title,
        }
    end
    return { path = value, pos = nil }
end

-- 事件路由
M.handlers = {}

function M.handlers.activate(event)
    local a = event.action
    if a == 'delete' then
        clear_clip_state()
        local container = id_to_path(event.menu_id)
        bookmarks.remove_at(container, event_index(event))
        rebuild(container)
    elseif a == 'rename' then
        M._show_rename_dialog(id_to_path(event.menu_id), event_index(event))
    elseif a == 'copy' then
        M._copy_or_cut(id_to_path(event.menu_id), event_index(event), 'copy')
    elseif a == 'cut' then
        M._copy_or_cut(id_to_path(event.menu_id), event_index(event), 'cut')
    elseif not a then
        if not event.value then return end
        if M.global_actions then M.global_actions.load_file(M._load_values(event.value)) end
        mp.commandv('script-message-to', 'uosc', 'close-menu')
    end
end

function M.handlers.key(event)
    local idx = event_index(event)
    if not idx then return end
    local container = id_to_path(event.menu_id)
    if event.id == 'del' then
        clear_clip_state()
        bookmarks.remove_at(container, idx)
        rebuild(container)
    elseif event.id == 'f2' then
        M._show_rename_dialog(container, idx)
    elseif event.id == 'ctrl+c' then
        M._copy_or_cut(container, idx, 'copy')
    elseif event.id == 'ctrl+x' then
        M._copy_or_cut(container, idx, 'cut')
    end
end

function M.handlers.move(event)
    clear_clip_state()
    local container = id_to_path(event.menu_id)
    bookmarks.move_in_container(container, event.from_index, event.to_index)
    rebuild(container, event.to_index)
end

function M.handlers.search(event)
    if event.menu_id == 'rename_bookmark' and event.query and event.query ~= '' then
        local container = pending.rename_container or {}
        local index = pending.rename_index
        if index then
            bookmarks.rename_at(container, index, event.query)
            rebuild(container, index, true)
        end
        pending.rename_container = nil
        pending.rename_index = nil
    elseif event.menu_id == 'paste_title' and event.query and event.query ~= '' then
        local t = pending.paste_target
        if t then
            local container = t.container or {}
            local index = t.index and (t.index + 1) or (#(bookmarks.resolve_container(container) or {}) + 1)
            pending.paste_target = nil
            -- 单 path 输入是手动新建收藏，不检查重复
            bookmarks.insert_at(container, index, { title = event.query, path = t.path })
            mp.osd_message(I18N.imported:format(1))
            rebuild(container, index, true)
        end
    end
end

function M.handlers.paste(event)
    local text = event.value
    if not text or text == '' then
        mp.osd_message(I18N.clipboard_empty)
        return
    end
    local container = id_to_path(event.menu_id)
    local index = event_index(event)
    if clip_state and text == clip_state.text then
        M._paste_from_clip_state(container, index)
    else
        clear_clip_state()
        M._import(container, index, text)
    end
end
--- 复制或剪切选中节点到剪贴板
function M._copy_or_cut(container, index, mode)
    local node = bookmarks.get_at(container, index)
    if not node then return end
    local text = utils.format_json(node)
    if not (clipboard and clipboard.set(text)) then
        mp.osd_message(I18N.clipboard_error)
        return
    end
    clip_state = { text = text, mode = mode, source = container, source_index = index }
    mp.osd_message(mode == 'cut' and I18N.cut_items or I18N.copied)
    if mode == 'cut' then
        rebuild(container, index)
    end
end

--- 粘贴脚本内复制/剪切的内容（剪切成功后才删除源节点）
function M._paste_from_clip_state(target_container, target_index)
    local src_container = clip_state.source
    local src_index = clip_state.source_index
    local is_cut = clip_state.mode == 'cut'

    local node = bookmarks.get_at(src_container, src_index)
    if not node then
        clip_state = nil
        return
    end

    local src_path = {}
    for _, p in ipairs(src_container) do table.insert(src_path, p) end
    table.insert(src_path, src_index)

    -- 不能粘贴到自身子树内（仅文件夹有子树；叶子无后代，避免数值索引相同造成的误判）
    if is_cut and type(node.items) == 'table'
        and bookmarks.is_descendant_path(src_path, target_container) then
        mp.osd_message(I18N.cannot_paste_into_self)
        return
    end

    local same_container = #target_container == #src_container
        and table.concat(target_container, '.') == table.concat(src_container, '.')

    -- 先解析目标容器：随后删除源节点会使索引路径失效（如根目录删一项后目标文件夹前移）
    local target_items = bookmarks.resolve_container(target_container)
    if not target_items then return end
    local count = #target_items

    -- 同容器剪切回原位置：无变化
    if is_cut and same_container then
        if target_index == src_index or (target_index == nil and src_index == count) then
            mp.osd_message(I18N.no_position_change)
            return
        end
    end

    -- 插入到选中条目的下一个；无选中则追加到末尾
    local ins = target_index and (target_index + 1) or (count + 1)
    local copy = bookmarks.clone_node(node)
    if not is_cut then bookmarks.strip_quick_mark(copy) end -- 复制剥离快速收藏标记，移动保留
    -- 叶子条目检查本层重复（文件夹直接添加）；同容器剪切排除自身
    if copy.path ~= nil then
        local skip = (is_cut and same_container) and src_index or nil
        if bookmarks.has_duplicate_in(target_items, copy.path, skip) then
            mp.osd_message(I18N.bookmark_exists)
            return
        end
    end
    if is_cut then
        bookmarks.remove_at(src_container, src_index)
        if same_container then
            if target_index == nil then
                ins = count          -- 移除后追加到末尾
            elseif target_index > src_index then
                ins = target_index   -- 移除后目标条目前移一位，插入位置相应前移
            end
        else
            -- 源在目标路径的前缀容器中时，删除后目标文件夹索引可能前移，重算路径用于重建菜单
            local prefix = #src_container < #target_container
            for i = 1, #src_container do
                if src_container[i] ~= target_container[i] then prefix = false break end
            end
            if prefix then
                local adjusted = {}
                for i, v in ipairs(target_container) do
                    if i <= #src_container then
                        adjusted[i] = v
                    elseif i == #src_container + 1 then
                        adjusted[i] = (src_index < v) and (v - 1) or v
                    else
                        adjusted[i] = v
                    end
                end
                target_container = adjusted
            end
        end
    end
    -- 直接向已解析的容器插入，避免删除源节点后路径失效
    if ins < 1 then ins = 1 elseif ins > #target_items + 1 then ins = #target_items + 1 end
    table.insert(target_items, ins, copy)
    bookmarks.invalidate_cache()
    if is_cut then
        clip_state = nil
        mp.osd_message(I18N.moved)
    else
        mp.osd_message(I18N.pasted)
    end
    rebuild(target_container, ins)
end

--- 从剪贴板文本解析可导入的节点；返回 nodes、skipped、单 path 内容、是否解析失败
--- 按首尾字符分三种情况：
---   1. {..}/[..]：按 JSON 解析；失败则把反斜杠转义为 \\ 后重试；再失败返回解析失败标志
---   2. ".."/'..'：去掉两边引号，字符串直接当作 path
---   3. 其他：直接当作 path
function M._parse_import(text)
    local trimmed = text:gsub('^%s+', '') :gsub('%s+$', '')
    local first = trimmed:sub(1, 1)
    local last = trimmed:sub(-1)

    -- 情况 1：JSON 数据
    if (first == '{' and last == '}') or (first == '[' and last == ']') then
        -- 依次尝试标准转义/字面反斜杠两种解释
        return M._parse_json_clipboard(trimmed)
    end

    -- 情况 2：引号包裹的 path
    local quoted = trimmed:match("^'(.-)'$") or trimmed:match('^"(.-)"$')
    if quoted then
        return nil, 0, quoted
    end

    -- 情况 3：其他一律当作 path
    return nil, 0, trimmed
end

--- 剪贴板 JSON 可能来自脚本/工具（标准转义）或手写（反斜杠是字面路径字符）。
--- 依次尝试两种解释，优先采用无坏节点者，否则取有效节点更多者。
function M._parse_json_clipboard(text)
    local interpretations = { text }
    local literal = text:gsub('\\', '\\\\')
    if literal ~= text then interpretations[2] = literal end

    local best_nodes, best_skipped
    for _, source in ipairs(interpretations) do
        local ok, parsed = pcall(utils.parse_json, source)
        if ok and type(parsed) == 'table' then
            local nodes, skipped = M._collect_import_nodes(parsed)
            if skipped == 0 then
                return nodes, skipped  -- 干净解释，直接采用（标准语义优先）
            end
            if not best_nodes or #nodes > #best_nodes then
                best_nodes, best_skipped = nodes, skipped
            end
        end
    end
    if best_nodes then return best_nodes, best_skipped end
    return nil, nil, nil, true  -- 两种解释都失败
end

--- 规范化 JSON 解析结果并收集可导入节点；返回 nodes 数组、跳过数量
function M._collect_import_nodes(parsed)
    local list = parsed[1] ~= nil and parsed or { parsed }
    local nodes = {}
    local skipped = 0
    for _, v in ipairs(list) do
        local node = M._normalize_import_node(v)
        if node then table.insert(nodes, node) else skipped = skipped + 1 end
    end
    return nodes, skipped
end

--- 路径中是否含控制字符（手写 JSON 未转义反斜杠可能被解析为 \n、\t 等控制符；真实路径不应包含）
local function path_has_control_chars(s)
    return type(s) == 'string' and s:find('[\001-\031]') ~= nil
end

--- 规范化导入节点：字符串→path 条目；{title,path}→条目；{title,value}→旧格式条目；{title,items}→文件夹
function M._normalize_import_node(v)
    if type(v) == 'string' and v ~= '' and not path_has_control_chars(v) then
        return { title = our_utils and our_utils.title_from_path(v) or v, path = v }
    end
    if type(v) == 'table' and type(v.title) == 'string' and v.title ~= '' then
        if type(v.items) == 'table' then
            local items = {}
            for _, child in ipairs(v.items) do
                local c = M._normalize_import_node(child)
                if c then table.insert(items, c) end
            end
            return bookmarks.strip_quick_mark({ title = v.title, items = items })
        elseif type(v.value) == 'string' and v.value ~= '' and not path_has_control_chars(v.value) then
            -- 兼容旧格式剪贴板 {title, value}
            return { title = v.title, path = v.value }
        elseif type(v.path) == 'string' and v.path ~= '' and not path_has_control_chars(v.path) then
            -- 历史菜单复制格式 {title, path}
            return { title = v.title, path = v.path }
        end
    end
    return nil
end

--- 导入剪贴板内容：单个 path 弹标题输入框，其余按识别结果插入
function M._import(container, index, text)
    if text:find('[\r\n]') and not text:find('^%s*[%[%{]') then
        mp.osd_message(I18N.clipboard_unrecognized)
        return
    end
    local nodes, skipped, parsed_string, parse_error = M._parse_import(text)
    if nodes == nil then
        -- JSON 解析失败（形似 {..}/[..] 且两次解析均失败）
        if parse_error then
            mp.osd_message(I18N.clipboard_unrecognized)
            return
        end
        -- 引号包裹/其他文本按单 path 处理
        if parsed_string and parsed_string ~= '' then
            text = parsed_string
        end
        pending.paste_target = {
            path = text:gsub('^%s+', ''):gsub('%s+$', ''),
            container = container,
            index = index,
        }
        -- URL 不预填标题，本地路径预填文件名
        local initial = ''
        if our_utils and not our_utils.is_url(text) then
            initial = our_utils.title_from_path(text) or ''
        end
        mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json(
            builder.input_dialog(I18N.paste_title_hint, { script_name, 'bookmark_menu_event' }, 'paste_title', initial)))
        return
    end
    if #nodes == 0 then
        mp.osd_message(I18N.clipboard_unrecognized)
        return
    end
    local base = index and (index + 1) or (#(bookmarks.resolve_container(container) or {}) + 1)
    local inserted = 0
    local dupes = 0
    for i, node in ipairs(nodes) do
        -- 叶子条目检查本层重复（文件夹直接添加，不跨层检查）
        if type(node.items) ~= 'table' and bookmarks.has_duplicate(container, node.path) then
            dupes = dupes + 1
        elseif bookmarks.insert_at(container, base + inserted, node) then
            inserted = inserted + 1
        end
    end
    local total_skipped = (skipped or 0) + dupes
    if total_skipped > 0 then
        mp.osd_message(I18N.imported_skipped:format(inserted, total_skipped))
    else
        mp.osd_message(I18N.imported:format(inserted))
    end
    rebuild(container, base + inserted - 1)
end

--- 显示重命名输入框（预填当前标题）
function M._show_rename_dialog(container, index)
    local node = bookmarks.get_at(container, index)
    if not node then return end
    pending.rename_container = container
    pending.rename_index = index
    mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json(
        builder.input_dialog(I18N.rename_bookmark_hint, { script_name, 'bookmark_menu_event' }, 'rename_bookmark',
            node.title or '')))
end

--- 收藏位置浏览器事件路由（与收藏菜单隔离：仅浏览/新建分组/添加到此处，支持搜索）
M.pick_handlers = {}

function M.pick_handlers.activate(event)
    local v = event.value
    if not v then return end
    if v.pick_new_folder then
        -- 两步"新建分组"：先记录当前位置，打开命名输入框
        pending.pick_create_path = pick_id_to_path(event.menu_id)
        mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json(
            builder.input_dialog(I18N.create_folder_tip, { script_name, 'bookmark_pick_event' }, 'pick_create_folder')))
    elseif v.pick_add_here then
        M._do_insert({ kind = 'path', path = pick_id_to_path(event.menu_id) })
    end
end

function M.pick_handlers.search(event)
    if event.menu_id == 'pick_create_folder' and event.query and event.query ~= '' then
        -- 仅创建分组并进入，随后由用户点击"添加到此处"
        local path = pending.pick_create_path or {}
        pending.pick_create_path = nil
        local idx = bookmarks.create_folder(path, event.query)
        if idx then
            local new_path = {}
            for _, p in ipairs(path) do table.insert(new_path, p) end
            table.insert(new_path, idx)
            M.open_picker(false, pick_id(new_path))
        end
    else
        -- 当前分组内按标题过滤分组节点
        local path = pick_id_to_path(event.menu_id)
        M.open_picker(true, event.menu_id, event.query, path)
    end
end

function M.handle_pick_event(json)
    local event = utils.parse_json(json)
    if not event or not event.type then return end
    local handler = M.pick_handlers[event.type]
    if type(handler) == 'function' then handler(event) end
end

function M.handle_event(json)
    local event = utils.parse_json(json)
    if not event or not event.type then return end
    local handler = M.handlers[event.type]
    if type(handler) == 'function' then handler(event) end
end

return M