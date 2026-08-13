-- 纯函数工具，不依赖 mpv API

local M = {}

--- 将秒数格式化为时间字符串
function M.format_time(s)
    if not s then
        return 'Unknown'
    end
    local minutes = math.floor((s % 3600) / 60)
    local seconds = s % 60
    if s < 3600 then
        return string.format('%02d:%02d', minutes, seconds)
    else
        return string.format('%d:%02d:%02d', math.floor(s / 3600), minutes, seconds)
    end
end

--- 根据重播阈值决定起始位置：已播进度超过阈值百分比则从头播放（0 = 始终从头；100 = 始终恢复）
function M.apply_restart_threshold(pos, duration, threshold)
    pos = pos or 0
    if threshold and threshold >= 0 and duration and duration > 0 then
        if pos / duration * 100 > threshold then
            return 0
        end
    end
    return pos
end

--- 检查路径是否为 URL（http/https/rtmp）
function M.is_url(path)
    return path:match('^http[s]?://') ~= nil or path:match('^rtmp://') ~= nil
end

--- 从文件路径提取文件夹信息：分组始终按视频所在的上层文件夹（不区分是否 Season）；
--- 仅当该文件夹是 "Season xx" 时，标题再向上取一层显示为 "XXX / Season xx"
function M.get_folder_info(path, utils)
    local upper_p1 = utils.split_path(path)
    local upper_p2, parent_d1 = utils.split_path(upper_p1:sub(1, -2))
    if parent_d1 == '' then
        return upper_p1, upper_p1
    elseif not string.find(parent_d1, '^[Ss]eason[^%a%d]*%d+') then
        return upper_p1, parent_d1
    else
        local upper_p3, parent_d2 = utils.split_path(upper_p2:sub(1, -2))
        if parent_d2 == '' then
            return upper_p1, string.format('%s / %s', upper_p2, parent_d1)
        else
            return upper_p1, string.format('%s / %s', parent_d2, parent_d1)
        end
    end
end

--- 搜索辅助：检查所有关键词是否匹配字符串（特殊字符按字面处理，* 作为通配符）
function M.keywords_match(query, str)
    if not query or query == '' then return true end
    str = string.lower(str)
    for word in string.gmatch(string.lower(query), '[^%s]+') do
        if word ~= '' then
            -- 先转义 Lua pattern 特殊字符，再把 * 还原为通配符
            local escaped = word:gsub('[%^%$%(%)%%%.%[%]%*%+%-%?]', '%%%0')
            local regex = escaped:gsub('%%%*', '.*')
            if not string.match(str, regex) then
                return false
            end
        end
    end
    return true
end

--- 从路径/URL 生成默认标题：URL 取域名，本地文件取去扩展名的文件名
function M.title_from_path(path)
    if M.is_url(path) then
        return path:match('^%a+://([^/]+)') or path
    end
    local name = path:match('([^/\\]+)$') or path
    name = name:gsub('%.[^%.\\/]+$', '')
    if name == '' then name = path end
    return name
end

return M