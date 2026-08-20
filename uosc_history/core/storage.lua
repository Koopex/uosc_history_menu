-- 基于 JSON 的持久化层（历史记录和收藏夹）

local M = {}

-- 当前数据文件版本（v4：收藏条目键名 value 改为 path；v3：历史记录键名改为 history_entries；v2 仍用 entries 键但为整数秒）
local CURRENT_VERSION = 4

local function get_mp()
    return require('mp')
end

--- 解析时长字符串为秒数，支持 "MM:SS" 和 "H:MM:SS"
local function parse_duration(str)
    if not str then return nil end
    local h, m, s = str:match('(%d+):(%d+):(%d+)')
    if h then return h * 3600 + m * 60 + s end
    local mm, ss = str:match('(%d+):(%d+)')
    if mm then return mm * 60 + ss end
    return nil
end

--- 将旧版本条目升级为 v2 格式：清除不再存储的字段、转换 progress、统一整数秒
local function normalize_entry(entry)
    if type(entry) ~= 'table' then return end

    entry.upper_path = nil
    entry.folder = nil
    -- 仅当时长缺失时从 progress 解析；progress 为旧版本存储字段，无论如何都清除
    if entry.duration == nil and type(entry.progress) == 'string' then
        local total = entry.progress:match('/([^/]+)%s*$') or entry.progress
        local dur = parse_duration(total)
        if dur then
            entry.duration = dur
        else
            entry.live = true
        end
    end
    entry.progress = nil

    if type(entry.pos) == 'number' then entry.pos = math.floor(entry.pos) end
    if type(entry.duration) == 'number' then entry.duration = math.floor(entry.duration) end
end

--- 迁移收藏节点：旧格式叶子使用 value 键，v4 起统一为 path（幂等，递归）
local function normalize_bookmark_node(node)
    if type(node) ~= 'table' then return end
    if node.value ~= nil then
        if node.path == nil then node.path = node.value end
        node.value = nil
    end
    if type(node.items) == 'table' then
        for _, child in ipairs(node.items) do
            normalize_bookmark_node(child)
        end
    end
end

--- 从日志文件加载数据
function M.load(data_path)
    local file, err = io.open(data_path, 'r')
    if not file then
        -- 数据文件不存在是首次运行时的正常情况，无需报错
        get_mp().msg.debug('Log file not found, start with empty data: ' .. tostring(data_path))
        return nil
    end

    local content = file:read('*a')
    file:close()

    if not content or content == '' then return nil end

    local ok, data = pcall(require('mp.utils').parse_json, content)
    if not ok or type(data) ~= 'table' then
        get_mp().msg.warn('Log file parse_json failed: ' .. (data or 'unknown error'))
        return nil
    end

    -- v3 起历史记录存储在 history_entries 键下，与 bookmark_entries 区分；v1/v2 使用 entries 键
    local entries = data.history_entries or data.entries or {}
    -- 旧版本数据（非当前版本）一次性升级到当前格式
    if data.version ~= CURRENT_VERSION then
        for _, entry in ipairs(entries) do
            normalize_entry(entry)
        end
    end
    -- 移除历史遗留的 pos_in_folder（字段已取消，避免旧数据一直回写）
    for _, entry in ipairs(entries) do
        if type(entry) == 'table' then entry.pos_in_folder = nil end
    end

    -- 收藏条目：v3 及更早使用 value 键，v4 起统一为 path（迁移幂等，总是执行）
    local bookmark_entries = data.bookmark_entries or {}
    for _, node in ipairs(bookmark_entries) do
        normalize_bookmark_node(node)
    end

    return {
        version = CURRENT_VERSION,
        options = data.options or {},
        entries = entries,
        bookmark_entries = bookmark_entries,
    }
end

--- 保存数据到日志文件
function M.save(data_path, data)
    local ok, json = pcall(require('mp.utils').format_json, {
        version = CURRENT_VERSION,
        options = data.options,
        history_entries = data.entries,
        bookmark_entries = data.bookmark_entries,
    })
    if not ok then
        get_mp().msg.error('Log file format_json failed: ' .. (json or 'unknown error'))
        return false
    end
    return M.atomic_write(data_path, json)
end

--- 原子写入：先写临时文件再重命名，避免中途崩溃损坏原文件
--- 确保文件所在目录存在（首次写入时自动创建，避免目录缺失导致写失败）
function M.ensure_parent_dir(path)
    local dir = path:match('^(.*)[/\\][^/\\]+$')
    if not dir or dir == '' then return end
    local platform = get_mp().get_property_native('platform')
    local args
    if platform == 'windows' then
        -- 路径可能含空格/中文：整体作为单个 -Command 参数传给 powershell
        args = { 'powershell', '-NoProfile', '-Command',
            'New-Item -ItemType Directory -Force -Path "' .. dir .. '" | Out-Null' }
    else
        args = { 'mkdir', '-p', dir }
    end
    pcall(require('mp.utils').subprocess, { args = args, cancellable = false })
end

function M.atomic_write(path, content)
    M.ensure_parent_dir(path)
    local tmp_path = path .. '.tmp'
    local file, err = io.open(tmp_path, 'w')
    if not file then
        get_mp().msg.error('Log file open failed: ' .. (err or 'unknown error'))
        return false
    end
    file:write(content)
    file:close()

    local ok, rerr = os.rename(tmp_path, path)
    if ok then return true end
    -- Windows 上 rename 到已存在文件会失败：先移除目标再重命名
    local d_ok, d_err = os.remove(path)
    if not d_ok then
        get_mp().msg.error('Log file remove failed: ' .. (d_err or 'unknown error'))
        return false
    end
    local ok2, rerr2 = os.rename(tmp_path, path)
    if not ok2 then
        get_mp().msg.error('Log file rename failed: ' .. (rerr2 or 'unknown error'))
        return false
    end
    return true
end

--- 加载收藏夹：从独立文件读取；文件不存在或为空时用 fallback 迁移写入并返回
function M.load_bookmarks(path, fallback)
    local file, err = io.open(path, 'r')
    if not file then
        if fallback and #fallback > 0 then
            M.save_bookmarks(path, fallback)
        end
        return fallback or {}
    end

    local content = file:read('*a')
    file:close()

    if not content or content == '' then
        if fallback and #fallback > 0 then
            M.save_bookmarks(path, fallback)
        end
        return fallback or {}
    end

    local ok, entries = pcall(require('mp.utils').parse_json, content)
    if not ok or type(entries) ~= 'table' then
        get_mp().msg.warn('Bookmarks file parse_json failed: ' .. (entries or 'unknown error'))
        return fallback or {}
    end
    -- 旧格式（value 键）迁移为当前格式（path 键）
    for _, node in ipairs(entries) do
        normalize_bookmark_node(node)
    end
    return entries
end

--- 保存收藏夹到独立文件（顶层数组，不带版本字段）
function M.save_bookmarks(path, entries)
    local ok, json = pcall(require('mp.utils').format_json, entries)
    if not ok then
        get_mp().msg.error('Bookmarks format_json failed: ' .. (json or 'unknown error'))
        return false
    end
    return M.atomic_write(path, json)
end

return M
