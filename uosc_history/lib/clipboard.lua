-- 剪贴板读写：优先 mpv clipboard/text 属性（Windows 可写），失败回退平台工具
-- 说明：mpv 的 clipboard/text 写入仅 Windows 支持（0.40 起），Linux/macOS 需调用外部工具

local M = {}

local mp
local mp_utils

function M.init(params)
    mp = params.mp
    mp_utils = params.utils
end

local function is_windows()
    return package.config:sub(1, 1) == '\\'
end

local function is_macos()
    return (jit and jit.os == 'OSX') or false
end

--- 运行外部命令（可选 stdin），成功返回 stdout
local function run(args, stdin)
    local res = mp_utils.subprocess({
        args = args,
        cancellable = false,
        capture_stdout = true,
        stdin_data = stdin,
    })
    if res and res.status == 0 then
        return res.stdout or ''
    end
    return nil
end

local function set_candidates()
    if is_macos() then return { { 'pbcopy' } } end
    local list = {}
    if os.getenv('WAYLAND_DISPLAY') then table.insert(list, { 'wl-copy' }) end
    if os.getenv('DISPLAY') then
        table.insert(list, { 'xclip', '-selection', 'clipboard' })
        table.insert(list, { 'xsel', '--clipboard', '--input' })
    end
    if #list == 0 then
        table.insert(list, { 'pbcopy' })
        table.insert(list, { 'wl-copy' })
        table.insert(list, { 'xclip', '-selection', 'clipboard' })
    end
    return list
end

local function get_candidates()
    if is_macos() then return { { 'pbpaste' } } end
    local list = {}
    if os.getenv('WAYLAND_DISPLAY') then table.insert(list, { 'wl-paste', '--no-newline' }) end
    if os.getenv('DISPLAY') then
        table.insert(list, { 'xclip', '-selection', 'clipboard', '-o' })
        table.insert(list, { 'xsel', '--clipboard', '--output' })
    end
    if #list == 0 then
        table.insert(list, { 'pbpaste' })
        table.insert(list, { 'wl-paste', '--no-newline' })
        table.insert(list, { 'xclip', '-selection', 'clipboard', '-o' })
    end
    return list
end

--- 写入剪贴板，成功返回 true
function M.set(text)
    if not is_windows() then
        for _, args in ipairs(set_candidates()) do
            if run(args, text) then return true end
        end
        return false
    end
    local ok = pcall(mp.set_property, 'clipboard/text', text)
    if ok then return true end
    -- Windows 属性失败兜底（罕见）
    return run({ 'powershell', '-NoProfile', '-Command', 'Set-Clipboard' }, text) ~= nil
end

--- 读取剪贴板，失败返回 nil
function M.get()
    local ok, value = pcall(mp.get_property, 'clipboard/text')
    if ok and value and value ~= '' then return value end
    for _, args in ipairs(get_candidates()) do
        local out = run(args)
        if out and out ~= '' then return out end
    end
    return nil
end

return M