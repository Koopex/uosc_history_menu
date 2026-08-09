-- 基于 JSON 的持久化层（历史记录和收藏夹）

local M = {}

-- 当前数据文件版本（v2：pos/duration 为整数秒，不再存储 upper_path/folder）
local CURRENT_VERSION = 2

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
    if not entry.duration then
        if entry.progress then
            local total = entry.progress:match('/([^/]+)%s*$') or entry.progress
            local dur = parse_duration(total)
            if dur then
                entry.duration = dur
            else
                entry.live = true
            end
            entry.progress = nil
        end
    end

    if type(entry.pos) == 'number' then entry.pos = math.floor(entry.pos) end
    if type(entry.duration) == 'number' then entry.duration = math.floor(entry.duration) end
end

--- 从日志文件加载数据
function M.load(data_path)
    local file, err = io.open(data_path, 'r')
    if not file then
        get_mp().msg.error('Log file open failed: ' .. (err or 'unknown error'))
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

    local entries = data.entries or {}
    -- 旧版本数据（非 v2）一次性升级到当前格式
    if data.version ~= CURRENT_VERSION then
        for _, entry in ipairs(entries) do
            normalize_entry(entry)
        end
    end

    return {
        version = CURRENT_VERSION,
        options = data.options or {},
        entries = entries,
        bookmark_entries = data.bookmark_entries or {},
    }
end

--- 保存数据到日志文件
function M.save(data_path, data)
    local ok, json = pcall(require('mp.utils').format_json, {
        version = CURRENT_VERSION,
        options = data.options,
        entries = data.entries,
        bookmark_entries = data.bookmark_entries,
    })
    if not ok then
        get_mp().msg.error('Log file format_json failed: ' .. (json or 'unknown error'))
        return false
    end

    local file, err = io.open(data_path, 'w')
    if not file then
        get_mp().msg.error('Log file open failed: ' .. (err or 'unknown error'))
        return false
    end

    file:write(json)
    file:close()
    return true
end

return M
