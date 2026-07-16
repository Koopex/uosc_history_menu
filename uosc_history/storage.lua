-- 基于 JSON 的持久化层（历史记录和收藏夹）

local M = {}

local function get_mp()
    return require('mp')
end

--- 从日志文件加载数据
function M.load(log_path)
    local file, err = io.open(log_path, 'r')
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

    return {
        options = data.options or {},
        entries = data.entries or {},
        bookmark_entries = data.bookmark_entries or {},
    }
end

--- 保存数据到日志文件
function M.save(log_path, data)
    local ok, json = pcall(require('mp.utils').format_json, {
        options = data.options,
        entries = data.entries,
        bookmark_entries = data.bookmark_entries,
    })
    if not ok then
        get_mp().msg.error('Log file format_json failed: ' .. (json or 'unknown error'))
        return false
    end

    local file, err = io.open(log_path, 'w')
    if not file then
        get_mp().msg.error('Log file open failed: ' .. (err or 'unknown error'))
        return false
    end

    file:write(json)
    file:close()
    return true
end

return M
