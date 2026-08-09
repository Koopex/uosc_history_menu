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

--- 列出同目录下同扩展名的视频文件名（自然排序，含扩展名过滤）
function M.list_dir_videos(path, utils, platform)
    local dir_path, file_name = utils.split_path(path)
    local ext = file_name:match('^.+()%..-$') and file_name:match('^.+(%..+)$') or ''

    local function alphanumsort(filenames)
        local function padnum(n, d)
            return #d > 0 and ('%03d%s%.12f'):format(#n, n, tonumber(d) / (10 ^ #d))
                or ('%03d%s'):format(#n, n)
        end
        local tuples = {}
        for i, f in ipairs(filenames) do
            tuples[i] = {f:lower():gsub('0*(%d+)%.?(%d*)', padnum), f}
        end
        table.sort(tuples, function(a, b)
            return a[1] == b[1] and #b[2] < #a[2] or a[1] < b[1]
        end)
        for i, tuple in ipairs(tuples) do
            filenames[i] = tuple[2]
        end
        return filenames
    end

    local filenames = {}
    if platform == 'windows' then
        local ps_command = string.format([[
            [Console]::OutputEncoding=[System.Text.UTF8Encoding]::new($false);
            Get-ChildItem -Name -LiteralPath '%s' -File -Filter '*%s'
        ]], dir_path, ext)
        local result = utils.subprocess({
            args = {'powershell', '-NoProfile', '-Command', ps_command},
            cancellable = false,
        })
        if result and result.stdout then
            for filename in string.gmatch(result.stdout, '[^\r\n]+') do
                table.insert(filenames, filename)
            end
        end
    else
        local result = utils.readdir(dir_path, 'files')
        for _, filename in ipairs(result or {}) do
            if filename:match('^.+(%..+)$') == ext then
                table.insert(filenames, filename)
            end
        end
    end

    alphanumsort(filenames)
    return filenames
end

--- 计算文件夹内位置字符串，如 "3 / 12"
function M.get_pos_in_folder(path, utils, platform)
    local _, file_name = utils.split_path(path)
    local filenames = M.list_dir_videos(path, utils, platform)
    local current = 0
    for i = 1, #filenames do
        if filenames[i] == file_name then
            current = i
            break
        end
    end
    return string.format('%s / %s', current, #filenames)
end

--- 搜索辅助：检查所有关键词是否匹配字符串
function M.keywords_match(query, str)
    str = string.lower(str)
    for word in string.gmatch(string.lower(query), '[^%s]+') do
        if word ~= '' then
            local regex = string.gsub(word, '%*', '.*')
            if not string.match(str, regex) then
                return false
            end
        end
    end
    return true
end

return M
