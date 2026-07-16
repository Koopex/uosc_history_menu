-- 播放历史数据模型
-- 管理原始条目数组和计算视图（全部/去重/文件夹）

local M = {}

local utils = require('mp.utils')

-- 原始条目（最新在前）
local entries = {}

-- 选项引用（log 标志、filename 偏好、filter）
local opts = {}

-- 计算视图缓存
local cache = { all = nil, dedup = nil, folders = nil }

--- 用加载的数据初始化/重置
function M.init(raw_entries, options)
    entries = raw_entries or {}
    opts = options or {}
    M.invalidate_cache()
end

--- 使所有计算视图缓存失效
function M.invalidate_cache()
    cache = { all = nil, dedup = nil, folders = nil }
end

--- 获取原始条目
function M.get_entries()
    return entries
end

--- 获取当前过滤设置
function M.get_filter()
    return opts.filter or 'recent'
end

--- 设置当前过滤
function M.set_filter(f)
    opts.filter = f
end

--- 在开头添加条目
function M.add(entry)
    table.insert(entries, 1, entry)
    M.invalidate_cache()
end

--- 按索引删除原始条目
function M.remove_at(index)
    table.remove(entries, index)
    M.invalidate_cache()
end

--- 按多个索引删除条目（降序排列避免偏移）
function M.remove_indices(indices)
    table.sort(indices, function(a, b) return a > b end)
    for _, i in ipairs(indices) do
        table.remove(entries, i)
    end
    M.invalidate_cache()
end

--- 清空所有条目
function M.clear()
    entries = {}
    M.invalidate_cache()
end

--- 计算并缓存三个视图
local function compute_views()
    if cache.all then return end

    cache.all = {}
    cache.dedup = {}
    cache.folders = {}

    local seen_path = {}
    local seen_upper_path = {}

    for i, entry in ipairs(entries) do
        if M.is_url_entry(entry) then
            local item = {
                title = entry.media_title or 'Unknown',
                hint = entry.datetime or '',
                value = {
                    path = entry.path,
                    pos = entry.pos,
                    url = true,
                    audio_path = entry.audio_path,
                    media_title = entry.media_title,
                },
            }
            table.insert(cache.all, item)

            if not seen_path[entry.path] then
                local dedup_item = {
                    title = entry.media_title or 'Unknown',
                    hint = entry.progress or '',
                    value = {
                        path = entry.path,
                        pos = entry.pos,
                        url = true,
                        audio_path = entry.audio_path,
                        media_title = entry.media_title,
                        peers = {i},
                    },
                }
                table.insert(cache.dedup, dedup_item)
                seen_path[entry.path] = #cache.dedup
                cache.all[#cache.all].dedup_index = #cache.dedup
            else
                table.insert(cache.dedup[seen_path[entry.path]].value.peers, i)
                cache.all[#cache.all].dedup_index = seen_path[entry.path]
            end
        else
            local title
            if opts.use_filename then
                _, title = utils.split_path(entry.path)
            else
                title = entry.media_title or 'Unknown'
            end

            local item = {
                title = title,
                hint = entry.datetime or '',
                value = { path = entry.path, pos = entry.pos },
            }
            table.insert(cache.all, item)

            if not seen_path[entry.path] then
                local dedup_item = {
                    title = title,
                    hint = entry.progress or '',
                    value = { path = entry.path, pos = entry.pos, peers = {i} },
                }
                table.insert(cache.dedup, dedup_item)
                seen_path[entry.path] = #cache.dedup
                cache.all[#cache.all].dedup_index = #cache.dedup

                if not seen_upper_path[entry.upper_path] then
                    local folder_item = {
                        title = entry.folder or '',
                        hint = entry.pos_in_folder or '',
                        value = { path = entry.path, pos = entry.pos, peers = {i} },
                    }
                    table.insert(cache.folders, folder_item)
                    seen_upper_path[entry.upper_path] = #cache.folders
                else
                    table.insert(cache.folders[seen_upper_path[entry.upper_path]].value.peers, i)
                end
            else
                table.insert(cache.dedup[seen_path[entry.path]].value.peers, i)
                table.insert(cache.folders[seen_upper_path[entry.upper_path]].value.peers, i)
                cache.all[#cache.all].dedup_index = seen_path[entry.path]
            end
        end
    end
end

--- 按过滤名称获取计算视图
function M.get_view(filter)
    compute_views()
    filter = filter or opts.filter or 'recent'
    if filter == 'all' then return cache.all
    elseif filter == 'by_folder' then return cache.folders
    else return cache.dedup end
end

--- 在当前过滤视图中搜索
function M.search(query, keyword_match_fn)
    local items = M.get_view()
    local results = {}
    for _, v in ipairs(items) do
        if keyword_match_fn(query, v.title) then
            table.insert(results, v)
        end
    end
    return results
end

--- 检查是否为 URL 条目
function M.is_url_entry(entry)
    return entry.url == true
end

--- 获取条目标题（用于书签）
function M.get_entry_title(index, use_filename)
    local entry = entries[index]
    if not entry then return 'Unknown' end
    if M.is_url_entry(entry) or not use_filename then
        return entry.media_title or 'Unknown'
    else
        local _, title = utils.split_path(entry.path)
        return title
    end
end

return M
