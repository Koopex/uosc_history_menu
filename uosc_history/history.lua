-- 播放历史数据模型
-- 管理原始条目数组和计算视图（全部/去重/文件夹）

local M = {}

local utils = require('mp.utils')

-- 原始条目（最新在前）
local entries = {}

-- 运行时状态选项（filter/log/quick_mark，随 JSON 持久化）
local opts = {}
-- 依赖注入（config 偏好、i18n 语言表、项目 utils）
local config = nil
local i18n = nil
local our_utils = nil

-- 计算视图缓存
local cache = { all = nil, dedup = nil, folders = nil }

--- 用加载的数据初始化/重置
function M.init(params)
    params = params or {}
    entries = params.entries or {}
    opts = params.opts or {}
    config = params.config or config
    i18n = params.i18n or i18n
    our_utils = params.utils or our_utils
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

--- 计算条目的进度提示：直播显示 live，否则现算已播 / 总时长
local function entry_hint(entry)
    if entry.live then
        return i18n and i18n.live or 'Live'
    end
    if entry.duration and entry.duration > 0 then
        local played = entry.pos or 0
        return (our_utils and our_utils.format_time(played) or tostring(played))
            .. ' / ' .. (our_utils and our_utils.format_time(entry.duration) or tostring(entry.duration))
    end
    return ''
end

--- 提取 URL 主机名（域名或 IP，含端口），失败返回 nil
local function url_host(path)
    return path and path:match('^%a[%w+.-]*://([^/]+)')
end

--- 计算并缓存三个视图
local function compute_views()
    if cache.all then return end

    cache.all = {}
    cache.dedup = {}
    cache.folders = {}

    local seen_path = {}
    local seen_upper_path = {}
    -- 文件夹视图中的 URL 域名分组（按主机名/IP 聚合，遍历时直接插入，与文件夹同序）
    local seen_url_host = {}

    for i, entry in ipairs(entries) do
        if M.is_url_entry(entry) then
            local title = '🔗  ' .. (entry.media_title or 'Unknown')
            -- 基础 value（URL 条目自带完整元数据）
            local url_value = {
                path = entry.path,
                pos = entry.pos,
                duration = entry.duration,
                url = true,
                audio_path = entry.audio_path,
                media_title = entry.media_title,
            }

            local item = {
                title = title,
                hint = entry.datetime or '',
                value = url_value,
            }
            table.insert(cache.all, item)

            if not seen_path[entry.path] then
                local dedup_value = {}
                for k, v in pairs(url_value) do dedup_value[k] = v end
                dedup_value.peers = {i}
                local dedup_item = {
                    title = title,
                    hint = entry_hint(entry),
                    value = dedup_value,
                }
                table.insert(cache.dedup, dedup_item)
                seen_path[entry.path] = #cache.dedup
                cache.all[#cache.all].dedup_index = #cache.dedup

                -- 文件夹视图：URL 按域名/IP 分组，首次遇到直接插入，后续记录进 peers
                local host = url_host(entry.path) or entry.path
                if not seen_url_host[host] then
                    local group_value = {}
                    for k, v in pairs(url_value) do group_value[k] = v end
                    group_value.peers = {i}
                    local group_item = {
                        title = '🔗  ' .. host,
                        hint = '',
                        value = group_value,
                        url_group = true,
                    }
                    table.insert(cache.folders, group_item)
                    seen_url_host[host] = #cache.folders
                else
                    table.insert(cache.folders[seen_url_host[host]].value.peers, i)
                end
            else
                table.insert(cache.dedup[seen_path[entry.path]].value.peers, i)
                local host = url_host(entry.path) or entry.path
                if seen_url_host[host] then
                    table.insert(cache.folders[seen_url_host[host]].value.peers, i)
                end
                cache.all[#cache.all].dedup_index = seen_path[entry.path]
            end
        else
            local title
            if config and config.use_filename then
                _, title = utils.split_path(entry.path)
            else
                title = entry.media_title or 'Unknown'
            end
            title = '🎬  ' .. title

            -- 分组键与标题从路径现算，保证新旧记录分组一致
            local group_key, folder_title = entry.upper_path, entry.folder
            if our_utils and our_utils.get_folder_info then
                group_key, folder_title = our_utils.get_folder_info(entry.path, utils)
            end

            -- 视图 value 携带完整元数据，菜单事件无需回查原始数组，避免视图索引错位
            local base_value = {
                path = entry.path,
                pos = entry.pos,
                duration = entry.duration,
                url = entry.url,
                audio_path = entry.audio_path,
                media_title = entry.media_title,
            }

            local item = {
                title = title,
                hint = entry.datetime or '',
                value = base_value,
            }
            table.insert(cache.all, item)

            if not seen_path[entry.path] then
                local dedup_value = {}
                for k, v in pairs(base_value) do dedup_value[k] = v end
                dedup_value.peers = {i}
                local dedup_item = {
                    title = title,
                    hint = entry_hint(entry),
                    value = dedup_value,
                }
                table.insert(cache.dedup, dedup_item)
                seen_path[entry.path] = #cache.dedup
                cache.all[#cache.all].dedup_index = #cache.dedup

                if not seen_upper_path[group_key] then
                    local folder_value = {}
                    for k, v in pairs(base_value) do folder_value[k] = v end
                    folder_value.peers = {i}
                    local folder_item = {
                        title = '📁  ' .. (folder_title or ''),
                        hint = entry.pos_in_folder or '',
                        value = folder_value,
                    }
                    table.insert(cache.folders, folder_item)
                    seen_upper_path[group_key] = #cache.folders
                else
                    table.insert(cache.folders[seen_upper_path[group_key]].value.peers, i)
                end
            else
                table.insert(cache.dedup[seen_path[entry.path]].value.peers, i)
                table.insert(cache.folders[seen_upper_path[group_key]].value.peers, i)
                cache.all[#cache.all].dedup_index = seen_path[entry.path]
            end
        end
    end

    -- URL 域名分组的 hint 显示同主机记录数
    for _, item in ipairs(cache.folders) do
        if item.url_group then
            item.hint = string.format(i18n and i18n.url_group_hint or '%d items', #item.value.peers)
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
