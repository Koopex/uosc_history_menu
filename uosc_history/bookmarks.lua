-- 收藏夹数据模型
-- 管理收藏夹分组和条目

local M = {}

-- entries: {title = string, items = {{title, value}, ...}} 数组
local entries = {}

-- 缓存的菜单项
local menu_items_cache = nil

--- 用加载的数据初始化
function M.init(params)
    params = params or {}
    entries = params.entries or {}
    M.invalidate_cache()
end

--- 使菜单项缓存失效
function M.invalidate_cache()
    menu_items_cache = nil
end

--- 获取原始条目（用于持久化）
function M.get_entries()
    return entries
end

--- 添加到已有分组
function M.add_to_folder(folder_index, item)
    local folder = entries[folder_index]
    if not folder then return nil end
    for _, existing in ipairs(folder.items) do
        if existing.value == item.value then return nil end -- 重复
    end
    table.insert(folder.items, item)
    M.invalidate_cache()
    return #folder.items
end

--- 添加条目到新分组（不存在则创建）
function M.add_to_new_folder(folder_name, item, insert_first)
    for i, v in ipairs(entries) do
        if v.title == folder_name then
            for _, existing in ipairs(v.items) do
                if existing.value == item.value then return i, #v.items, false end
            end
            table.insert(v.items, item)
            M.invalidate_cache()
            return i, #v.items, false
        end
    end
    local new_folder = { title = folder_name, items = {item} }
    if insert_first then
        table.insert(entries, 1, new_folder)
        M.invalidate_cache()
        return 1, 1, true
    else
        table.insert(entries, new_folder)
        M.invalidate_cache()
        return #entries, 1, true
    end
end

--- 删除分组中的条目
function M.remove_item(folder_index, item_index)
    local folder = entries[folder_index]
    if not folder then return end
    table.remove(folder.items, item_index)
    M.invalidate_cache()
end

--- 删除整个分组
function M.remove_folder(folder_index)
    table.remove(entries, folder_index)
    M.invalidate_cache()
end

--- 在分组内移动条目
function M.move_item(folder_index, from_index, to_index)
    local folder = entries[folder_index]
    if not folder then return end
    local item = table.remove(folder.items, from_index)
    table.insert(folder.items, to_index, item)
    M.invalidate_cache()
end

--- 移动整个分组
function M.move_folder(from_index, to_index)
    local item = table.remove(entries, from_index)
    table.insert(entries, to_index, item)
    M.invalidate_cache()
end

--- 重命名条目
function M.rename_item(folder_index, item_index, new_title)
    local folder = entries[folder_index]
    if not folder then return end
    folder.items[item_index].title = new_title
    M.invalidate_cache()
end

--- 重命名分组
function M.rename_folder(folder_index, new_title)
    if not entries[folder_index] then return end
    entries[folder_index].title = new_title
    M.invalidate_cache()
end

--- 清空所有收藏
function M.clear()
    entries = {}
    M.invalidate_cache()
end

--- 构建并返回菜单项（含 item_actions、on_move 等）
function M.get_menu_items(callback_table, msg)
    if menu_items_cache then return menu_items_cache end
    menu_items_cache = {}
    for _, v in ipairs(entries) do
        local folder = { title = v.title, items = {} }
        for _, w in ipairs(v.items) do
            table.insert(folder.items, { title = w.title, value = w.value })
        end
        folder.item_actions = {
            { name = 'change', icon = 'reply_all', label = msg.change_folder },
            { name = 'rename', icon = 'edit', label = msg.rename_bookmark },
            { name = 'delete', icon = 'delete', label = msg.del_bookmark },
        }
        folder.item_actions_place = 'outside'
        folder.on_move = 'callback'
        folder.callback = callback_table
        folder.footnote = msg.move_bookmark_up .. '   ' .. msg.move_bookmark_down
            .. '   ' .. msg.delete_key .. '   ' .. msg.rename_bookmarks
        table.insert(menu_items_cache, folder)
    end
    return menu_items_cache
end

return M
