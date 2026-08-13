-- 收藏夹数据模型
-- 管理收藏夹分组和条目（支持任意层级嵌套）

local M = {}

-- entries: 顶层数组，元素可为文件夹 {title, items={...}} 或条目 {title, path}
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

--- 深拷贝节点（条目/文件夹子树），避免复制/剪切后与原数据共享引用
function M.clone_node(node)
    local copy = {}
    for k, v in pairs(node) do
        if type(v) == 'table' then
            local nested = {}
            for i, child in ipairs(v) do nested[i] = M.clone_node(child) end
            copy[k] = nested
        else
            copy[k] = v
        end
    end
    return copy
end

--- 解析容器路径：{} = 根，{2} = entries[2].items，{2,1} = entries[2].items[1].items
function M.resolve_container(path_list)
    local container = entries
    for _, idx in ipairs(path_list or {}) do
        container = container[idx]
        if type(container) ~= 'table' or container.items == nil then return nil end
        container = container.items
    end
    return container
end

--- 取容器中指定位置的节点
function M.get_at(path_list, index)
    local container = M.resolve_container(path_list)
    if not container then return nil end
    return container[index]
end

--- 删除容器中指定位置的节点
function M.remove_at(path_list, index)
    local container = M.resolve_container(path_list)
    if not container or not container[index] then return end
    table.remove(container, index)
    M.invalidate_cache()
end

--- 在容器指定位置上方插入节点（index 越界时收拢到边界），返回实际索引
function M.insert_at(path_list, index, node)
    local container = M.resolve_container(path_list)
    if not container then return nil end
    local count = #container
    if not index or index < 1 then index = 1 elseif index > count + 1 then index = count + 1 end
    table.insert(container, index, node)
    M.invalidate_cache()
    return index
end

--- 追加到容器末尾，返回索引
function M.append_to(path_list, node)
    local container = M.resolve_container(path_list)
    if not container then return nil end
    table.insert(container, node)
    M.invalidate_cache()
    return #container
end

--- 容器内移动（同层排序）
function M.move_in_container(path_list, from_index, to_index)
    local container = M.resolve_container(path_list)
    if not container then return end
    local item = container[from_index]
    if not item or from_index == to_index then return end
    table.remove(container, from_index)
    table.insert(container, to_index, item)
    M.invalidate_cache()
end

--- 重命名容器中指定位置的节点
function M.rename_at(path_list, index, new_title)
    local node = M.get_at(path_list, index)
    if not node then return end
    node.title = new_title
    M.invalidate_cache()
end

--- target_path 是否为 source_path 自身或其子树（含相等：粘贴进自身容器同样构成循环）
function M.is_descendant_path(source_path, target_path)
    if #target_path < #source_path then return false end
    for i = 1, #source_path do
        if target_path[i] ~= source_path[i] then return false end
    end
    return true
end

--- 按路径向分组添加条目（path_list 为数组，{} = 根），重复返回 nil
function M.add_to_folder_path(path_list, item)
    local container = M.resolve_container(path_list)
    if not container then return nil end
    for _, existing in ipairs(container) do
        if item.path ~= nil and existing.path == item.path then return nil end -- 重复（文件夹节点不检查）
    end
    table.insert(container, item)
    M.invalidate_cache()
    return #container
end

--- 在容器末尾新建分组，返回索引（失败返回 nil）
function M.create_folder(path_list, name)
    local container = M.resolve_container(path_list)
    if not container then return nil end
    table.insert(container, { title = name, items = {} })
    M.invalidate_cache()
    return #container
end

--- 添加到快速收藏分组（带 quick_mark 标记的分组；不存在则在索引 1 创建）
--- 返回 folder_index, item_index, status：status = 'created'|'added'|'duplicate'
function M.add_to_quick_folder(item, folder_name)
    for i, v in ipairs(entries) do
        if v.quick_mark and v.items ~= nil then
            for _, existing in ipairs(v.items) do
                if item.path ~= nil and existing.path == item.path then return i, nil, 'duplicate' end
            end
            table.insert(v.items, item)
            M.invalidate_cache()
            return i, #v.items, 'added'
        end
    end
    -- 兼容旧数据：无标记分组时，将同名分组升级为快速收藏分组
    for i, v in ipairs(entries) do
        if v.title == folder_name and v.items ~= nil then
            v.quick_mark = true
            for _, existing in ipairs(v.items) do
                if item.path ~= nil and existing.path == item.path then return i, nil, 'duplicate' end
            end
            table.insert(v.items, item)
            M.invalidate_cache()
            return i, #v.items, 'added'
        end
    end
    local new_folder = { title = folder_name or '快速收藏', quick_mark = true, items = {item} }
    table.insert(entries, 1, new_folder)
    M.invalidate_cache()
    return 1, 1, 'created'
end

--- 快速收藏分组索引：带 quick_mark 标记的分组；不存在则创建并返回（索引 1）
function M.get_quick_folder_index(folder_name)
    for i, v in ipairs(entries) do
        if v.quick_mark and v.items ~= nil then return i end
    end
    for i, v in ipairs(entries) do
        if v.title == (folder_name or '快速收藏') and v.items ~= nil then
            v.quick_mark = true
            M.invalidate_cache()
            return i
        end
    end
    local new_folder = { title = folder_name or '快速收藏', quick_mark = true, items = {} }
    table.insert(entries, 1, new_folder)
    M.invalidate_cache()
    return 1
end

--- 容器内是否存在相同 value 的叶子条目（只检查本层，不跨层）；skip_index 用于排除自身
function M.has_duplicate(path_list, value, skip_index)
    local container = M.resolve_container(path_list)
    if not container then return false end
    for i, node in ipairs(container) do
        if i ~= skip_index and type(node) == 'table' and node.path ~= nil and node.path == value then
            return true
        end
    end
    return false
end

--- 已解析容器内是否存在相同 path 的叶子条目（只检查本层，不跨层）；skip_index 用于排除自身
function M.has_duplicate_in(items, value, skip_index)
    if not items then return false end
    for i, node in ipairs(items) do
        if i ~= skip_index and type(node) == 'table' and node.path ~= nil and node.path == value then
            return true
        end
    end
    return false
end

--- 递归剥离快速收藏标记（复制/导入时使用）
function M.strip_quick_mark(node)
    node.quick_mark = nil
    if node.items then
        for _, child in ipairs(node.items) do M.strip_quick_mark(child) end
    end
    return node
end

--- 清空所有收藏
function M.clear()
    entries = {}
    M.invalidate_cache()
end

--- 叶子条目操作按钮
local function leaf_actions(msg)
    return {
        { name = 'rename', icon = 'edit', label = msg.rename },
        { name = 'copy', icon = 'content_copy', label = msg.copy },
        { name = 'cut', icon = 'content_cut', label = msg.cut },
        { name = 'delete', icon = 'delete', label = msg.delete },
    }
end

--- 递归构建菜单项：文件夹（带 items）→ 子菜单（显式 id=索引路径），条目 → 直接项（含操作按钮）
local function build_menu_items(list, callback_table, msg, path_prefix)
    local result = {}
    for i, node in ipairs(list) do
        if type(node) == 'table' then
            local node_path = {}
            for _, p in ipairs(path_prefix) do table.insert(node_path, p) end
            table.insert(node_path, i)
            local id = 'bookmarks' .. (#node_path > 0 and '.' .. table.concat(node_path, '.') or '')
            if node.items ~= nil then
                local sub = {
                    id = id,
                    title = node.title or (msg.unknown or 'Unknown'),
                    items = build_menu_items(node.items, callback_table, msg, node_path),
                    on_move = 'callback',
                    on_paste = 'callback',
                    callback = callback_table,
                    footnote = msg.bookmark_footnote,
                }
                table.insert(result, sub)
            else
                table.insert(result, {
                    id = id,
                    title = node.title or (msg.unknown or 'Unknown'),
                    value = node.path,
                    actions = leaf_actions(msg),
                })
            end
        end
    end
    return result
end

--- 构建并返回菜单项（支持任意层级嵌套：文件夹 ↔ 条目混合）
function M.get_menu_items(callback_table, msg)
    if menu_items_cache then return menu_items_cache end
    menu_items_cache = build_menu_items(entries, callback_table, msg, {})
    return menu_items_cache
end

return M