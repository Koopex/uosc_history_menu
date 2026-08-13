-- 播放历史数据模型
-- 管理原始条目数组和计算视图（全部/去重/来源分组）

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

-- 计算视图缓存（dedup_index：path → 去重表条目，惰性构建）
local cache = { all = nil, dedup = nil, folders = nil, dedup_index = nil }

--- 用加载的数据初始化/重置
function M.init(params)
    params = params or {}
    entries = params.entries or {}
    opts = params.opts or {}
    config = params.config or config
    i18n = params.i18n or i18n
    our_utils = params.utils or our_utils
    M.apply_limit()
    M.invalidate_cache()
end

--- 使所有计算视图缓存失效
function M.invalidate_cache()
    cache = { all = nil, dedup = nil, folders = nil, dedup_index = nil }
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
    M.apply_limit()
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

--- 按 max_entries 裁剪最旧条目（0 或未设置 = 不限制）
function M.apply_limit()
    local max = config and config.max_entries
    if not max or max <= 0 then return end
    if #entries > max then
        for i = #entries, max + 1, -1 do
            entries[i] = nil
        end
    end
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

--- 判断目录名是否为 "Season xx" 格式（如 Season 1 / season 01）
local function is_season_name(name)
    return name ~= nil and name ~= '' and name:match('^[Ss]eason[^%a%d]*%d+') ~= nil
end

--- 取目录路径的最后一段作为名称；无父目录时返回 nil
local function dir_name(dir)
    if not dir or dir == '' then return nil end
    local _, name = utils.split_path(dir:sub(1, -2))
    if name == '' then return nil end
    return name
end

--- 归一化分组键（统一分隔符，避免同目录因 \ 与 / 混用被拆成两组）
local function norm_key(p)
    return p and p:gsub('\\', '/') or ''
end

--- 从去重表构建“按来源分组”嵌套视图：
--- 本地文件按目录归类（父目录为 Season xx 时再向上取一层系列根目录，形成三层菜单），
--- URL 按域名/IP 归类；叶子节点直接复用去重表条目（图标/hint/value 完全一致）
local function build_source_view(dedup_items)
    local roots = {}
    local root_by_key = {}
    local season_by_key = {}

    for _, item in ipairs(dedup_items) do
        local value = item.value
        local path = value and value.path
        if path and path ~= '' then
            if value.url then
                local host = url_host(path) or path
                local key = 'u:' .. norm_key(host)
                local root = root_by_key[key]
                if not root then
                    root = { id = 'by_folder.' .. key, title = '🔗  ' .. host, items = {} }
                    table.insert(roots, root)
                    root_by_key[key] = root
                end
                table.insert(root.items, item)
            else
                local dir = utils.split_path(path)
                local parent = dir_name(dir)
                if is_season_name(parent) then
                    -- 三层：系列根目录 → Season xx → 文件
                    local grand_dir = utils.split_path(dir:sub(1, -2))
                    local grand_name = dir_name(grand_dir)
                    local root_key = 'd:' .. norm_key(grand_dir)
                    local root = root_by_key[root_key]
                    if not root then
                        root = { id = 'by_folder.' .. root_key, title = '📁  ' .. (grand_name or parent), items = {} }
                        table.insert(roots, root)
                        root_by_key[root_key] = root
                    end
                    local season_key = root_key .. '|' .. norm_key(dir)
                    local season = season_by_key[season_key]
                    if not season then
                        season = { id = 'by_folder.' .. season_key, title = '📁  ' .. parent, items = {} }
                        table.insert(root.items, season)
                        season_by_key[season_key] = season
                    end
                    table.insert(season.items, item)
                else
                    -- 两层：父目录 → 文件
                    local root_key = 'd:' .. norm_key(dir)
                    local root = root_by_key[root_key]
                    if not root then
                        root = { id = 'by_folder.' .. root_key, title = '📁  ' .. (parent or dir), items = {} }
                        table.insert(roots, root)
                        root_by_key[root_key] = root
                    end
                    table.insert(root.items, item)
                end
            end
        end
    end
    return roots
end

--- 计算并缓存三个视图
local function compute_views()
    if cache.all then return end

    cache.all = {}
    cache.dedup = {}

    local seen_path = {}

    for i, entry in ipairs(entries) do
        -- 无路径的损坏条目直接跳过，避免分组计算崩溃
        if entry.path and entry.path ~= '' then
            local title
            local base_value = {
                path = entry.path,
                pos = entry.pos,
                duration = entry.duration,
                url = entry.url,
                audio_path = entry.audio_path,
                media_title = entry.media_title,
            }
            -- 每个视图叶子都带原始条目索引（peers），搜索/过滤后仍能正确定位
            base_value.peers = { i }
            if M.is_url_entry(entry) then
                title = '🔗  ' .. (entry.media_title or i18n.unknown)
                base_value.url = true
            else
                if config and config.use_filename then
                    _, title = utils.split_path(entry.path)
                else
                    title = entry.media_title or i18n.unknown
                end
                title = '🎬  ' .. title
            end

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
            else
                table.insert(cache.dedup[seen_path[entry.path]].value.peers, i)
                cache.all[#cache.all].dedup_index = seen_path[entry.path]
            end
        end
    end

    cache.folders = build_source_view(cache.dedup)
end

--- 按过滤名称获取计算视图
function M.get_view(filter)
    compute_views()
    filter = filter or opts.filter or 'recent'
    if filter == 'all' then return cache.all
    elseif filter == 'by_folder' then return cache.folders
    else return cache.dedup end
end

--- 从去重表中按路径查找最新条目（返回整个菜单条目，含 hint/value/标题）
function M.get_dedup_by_path(path)
    if not path then return nil end
    compute_views()
    if not cache.dedup_index then
        cache.dedup_index = {}
        for _, item in ipairs(cache.dedup) do
            local p = item.value and item.value.path
            if p and not cache.dedup_index[p] then
                cache.dedup_index[p] = item
            end
        end
    end
    return cache.dedup_index[path]
end

--- 检查是否为 URL 条目
function M.is_url_entry(entry)
    return entry.url == true
end

return M
