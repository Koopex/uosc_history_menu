local mp = require 'mp'
local utils = require 'mp.utils'
local o ={ 
	language = 'en',
	log = true,
	space = true,
	start_action = 'menu',
	menu_filter = 'all',
	last_video = true,
	hint = 'position+duration',
	log_url = false,
	simplified_media_title = false,
	blocked_words = '',
	log_path = '/:dir%mpvconf%/uosc_history_menu.log' ,
}


(require 'mp.options').read_options(o)
if o.log_path:match('^/:dir%%mpvconf%%') then 
	o.log_path = o.log_path:gsub('/:dir%%mpvconf%%', mp.find_config_file('.'))
elseif o.log_path:match('^/:dir%%script%%') then
	o.log_path = o.log_path:gsub('/:dir%%script%%', mp.find_config_file('scripts'))
elseif o.log_path:match('^/:var%%(.*)%%') then
	local os_variable = o.log_path:match('/:var%%(.*)%%')
	o.log_path = o.log_path:gsub('/:var%%(.*)%%', os.getenv(os_variable))
end


local t = {}
if o.language == 'en' then
	t = {
		del = 'Press "Delete" to remove from history',
		title_all = 'Recently Played (All)',
		title_deduplicated = 'Recently Played (Deduplicated)',
		title_folders = 'Recently Played (Folders)',
		footnote = 'Press ← / → to switch filter modes   Press Ctrl+F to search',
		clear = 'Clear playback history',
		yes = 'YES',
		no = 'NO',
		tooltip = 'Recently Played',
	}
elseif o.language == 'zh' then
	t = {
		del = '删除该记录：按下“Delete”',
		title_all = '播放记录（全部）',
		title_deduplicated = '播放记录（目录）',
		title_folders = '播放记录（目录）',
		footnote = '切换过滤方式:← / →   搜索记录:Ctrl+f',
		clear = '清空播放记录?',
		yes = '确定',
		no = '取消',
		tooltip = '播放记录',
	}
end


local loaded = false -- 区分"刚打开的idle"和"关闭文件后的idle"
local logable = false -- 防止重复记录
local menu_showing = false -- 记录菜单的开闭状态
local from_mpv = false -- 区分"直接打开视频"和"用此脚本打开的视频"
local time_pos = 0 -- 关闭文件时的播放时长
local seek_time = '' -- 恢复上次的播放
local http_media_title = '' -- 记录url标题
local http_audio_path = 'null' -- 记录url音频链接
local log_part = {} -- 前半部分日志
local items = {} -- 记录菜单条目, 不用反复获取
local words = {} -- 屏蔽词, 只有在开启简化标题时加载


if o.simplified_media_title then	-- 如果开机简化标题就把屏蔽词加载进来
	for part in string.gmatch(o.blocked_words, "[^,]+") do
		table.insert(words, part)
	end
end


local function formatPercent(a,b) -- 计算播放进度
	if a == nil then return ''
	else return string.format('%2d%%', math.floor(tonumber(a) / tonumber(b) * 100 + 0.5))
	end
end


local function formatTime(sec)	-- 把"秒"转为"时:分:秒"
	if sec == nil then return '' else 
		local s = tonumber(sec)
		local hours = math.floor(s / 3600)
		local minutes = math.floor((s % 3600) / 60)
		local seconds = s % 60
		if s < 3600 then return string.format('%02d:%02d', minutes, seconds)
		else return string.format('%d:%02d:%02d', hours, minutes, seconds)
		end		
	end
end


local function simplifyTitle(str) -- 简化标题, 不需要的规则注释掉即可													
	str = str:gsub('%.%w+[^%.]*$', '') 					-- 移除后缀名
	
	str = string.gsub(str, '%b[]', function(s)  				-- 移除 '[xxx]' 但保留 '[数字]' 	(保留集数)
		return s:match('^%[%d+%]$') and s or '' end)	
		
	for _, word in ipairs(words) do 						-- 移除屏蔽词
		str = str:gsub(word, '') end

	str = str:gsub('^%s+', '') 							-- 移除开头的空格
	str = str:gsub("%(%s*%)", "") 						-- 移除空括号 '()'
	str = str:gsub('%.%.+', '.') 							-- 移除重复的 '.'
	str = str:gsub('%s%s+', ' ') 							-- 移除重复的 '.'
	str = str:gsub("%s*[%.%-]-%s*$", ""):gsub("%s*$", "") 	-- 移除末尾的 '.' 和 '-'
	return str
end


local function findPosition(path) -- 找到视频在文件夹中的排序
	local upper_path, file_name = utils.split_path(path)
	local entries = utils.readdir(upper_path, "files")
	local file_type = file_name:match(".+%.(%w+)$")
	local videos = {}
	for i, file in ipairs(entries) do
		if file:match(".+%.(%w+)$") == file_type then
			table.insert(videos, file)
		end
	end
	table.sort(videos)
	local a = 0
	for i, v in ipairs(videos) do
		if v == file_name then
			a = i
		end
	end
	return string.format('%d / %d', a, #videos)
end


local function readLogFile() -- 读日志, 转为表格
	local content = ''
	local file = io.open(o.log_path, 'r')
	if not file then 
		local f = io.open(o.log_path, 'w') 
	else 
		content = file:read('*a') 
		file:close()
	end
	local array = {}	
	if content ~= '' then
		for line in content:gmatch("([^\n]+)") do
			local parts = {}
			for part in line:gmatch("([^,]+)") do
				table.insert(parts, part)
			end
-- 每行日志记录的内容:  1 日期时间  2 媒体标题  3 文件名  4 文件路径  5 上一级路径  6 文件夹名  7 在目录中的位置  8 播放进度(秒)  9 播放进度(时分秒)  10 视频时长(时分秒) 11播放进度(百分比) 
			table.insert(array, {					--从日志构建出的表格, 每个条目有以下属性
				date_time = parts[1],			--1 日期时间			date_time
				media_title = parts[2],			--2 媒体标题			media_title
				file_name = parts[3],			--3 文件名			file_name
				path = parts[4],				--4 文件路径			path
				upper_path = parts[5],			--5 上一级路径			upper_path
				parent_folder = parts[6], 			--6 文件夹名			parent_folder
				position_in_folder = parts[7],		--7 在目录中的位置		position_in_folder
				position_sec = parts[8],			--8 播放进度(秒)		position_sec
				position_for = parts[9],			--9 播放进度(时分秒)	position_for
				duration_for = parts[10],			--10视频时长(时分秒)	duration_for
				percent = parts[11],				--11播放进度(百分比)	percent
				})
		end
	end
	return array
end


local function getItems() -- 从日志条目提取内容用来组建菜单
	local arry = readLogFile()
	local seen = {}
	local entries = {}
	if next(arry) ~= nill then
		if o.menu_filter == 'folders' then
			for i = #arry, 1, -1 do
				local v = arry[i]
				local x = ''
				if v.position_in_folder ~= 'url' then
					x = v.upper_path
				else
					x = v.media_title
				end
				if not seen[x] then
					table.insert(entries, v)
					seen[x] = true
				end
			end
		elseif o.menu_filter == 'deduplicated' then
			for i = #arry, 1, -1 do
				local v = arry[i]
				local x = ''
				if v.position_in_folder ~= 'url' then
					x = v.path
				else
					x = v.media_title
				end
				if not seen[x] then
					table.insert(entries, v)
					seen[x] = true
				end
			end
		elseif o.menu_filter == 'all' then
			for i = #arry, 1, -1 do
				local v = arry[i]
				table.insert(entries, v)
			end	
		end
	end
	local title = ''
	local result = {}
	for i, arr in ipairs(entries, parts) do
		local parts = {}
		for j, part in ipairs(arr) do
			table.insert(parts, part)    
		end
		--[[从日志构建出的表格, 每个条目由以下属性构成
		1 日期时间		date_time
		2 媒体标题		media_title
		3 文件名			file_name
		4 文件路径		path
		5 上一级路径		upper_path
		6 文件夹名		parent_folder
		7 在目录中的位置	position_in_folder
		8 播放进度(秒)		position_sec
		9 播放进度(时分秒)	position_for
		10视频时长(时分秒)	duration_for
		11播放进度(百分比)	percent
		--]]			
		local title = ''
		if o.menu_filter ~= 'folders' then 
			title = arr.media_title			
		else
			if o.simplified_media_title then
				if string.find(arr.parent_folder, '^[Ss]eason[^%a%d]*%d+') ~= nil then
					title = '/' .. simplifyTitle(arr.path:gsub('\\[^\\]*$', ''):gsub('\\[^\\]*$', ''):match('([^\\]+)$'))
				else	
					title = '/' .. simplifyTitle(arr.parent_folder)
				end
			else
				if string.find(arr.parent_folder, '^[Ss]eason[^%a%d]*%d+') ~= nil then
					title = '/' .. arr.path:gsub('\\[^\\]*$', ''):gsub('\\[^\\]*$', ''):match('([^\\]+)$')
				else
					title = '/' .. arr.parent_folder
				end			
			end
		end
		local hint = ''
		local icon = ''
		local actions = {{name = 'delete', icon = 'delete', label = t.del},}
		local active = false
		if o.menu_filter == 'deduplicated' then
			if o.hint == 'percent' then hint = arr.percent
			elseif o.hint == 'position+duration' then hint = string.format('%s / %s', arr.position_for, arr.duration_for) 
			elseif o.hint == 'percent+duration' then hint = string.format('%s  %s', arr.percent, arr.duration_for)
			end
		elseif o.menu_filter == 'all' then
			hint = arr.date_time:sub(2, -5)
		elseif o.menu_filter == 'folders' then
			hint = arr.position_in_folder 
		end										------- 按键返回值 --------
		if arr.position_in_folder ~= 'url' then					-- 本地文件:	1 播放进度	2 视频路径
			table.insert(result, {title = title, hint = hint, value = {arr.position_sec, arr.path}, icon = icon, active = active, actions = actions, })
		else												-- url:	1 播放进度	2 视频路径	3 音频路径	4 媒体标题
			table.insert(result, {title = title, hint = hint, value = {arr.position_sec, arr.path, arr.upper_path, arr.media_title}, icon = icon, active = active, actions = actions, })			
		end
	end
	items = result
end


local function openMenu(num) -- 打开菜单
	local menu_props = {}
	local menu_title = ''
	if o.menu_filter == 'all' then menu_title = t.title_all
	elseif o.menu_filter == 'deduplicated' then menu_title = t.title_deduplicated
	elseif o.menu_filter == 'folders' then menu_title = t.title_folders end
	menu_props = {type = 'history_list', title = menu_title, selected_index = num, callback = {mp.get_script_name(), 'menu_event'},items = items, footnote = t.footnote,}
	mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json(menu_props))
end


local function updateMenu(num) -- 更新菜单(删除记录后使用)
	local menu_props = {}
	local menu_title = ''
	if o.menu_filter == 'all' then menu_title = t.title_all
	elseif o.menu_filter == 'deduplicated' then menu_title = t.title_deduplicated
	elseif o.menu_filter == 'folders' then menu_title = t.title_folders end	
	menu_props = {type = 'history_list', title = menu_title, selected_index = num, callback = {mp.get_script_name(), 'menu_event'},items = items, footnote = t.footnote,}
	mp.commandv('script-message-to', 'uosc', 'update-menu', utils.format_json(menu_props))
end


local function confirm() -- 清空记录前确认
	local menu_props = {type = 'history_list', title = t.clear,
		items = {
			{title = t.yes, align = 'center', bold = 'true', value = {'script-message-to', mp.get_script_name(), 'do_clear_history'},}, 
			{title = t.no, align = 'center', bold = 'true', value = {'ignore'},},
			},
		selected_index = 2, search_style = 'disabled',}
	mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json(menu_props))
end


local function clearHistory() -- 清空记录
	io.open(o.log_path, 'w'):close() 
	getItems()
end


local function toggleMenu() -- 开关菜单
	local menu_type = mp.get_property_native('user-data/uosc/menu/type')
	if menu_type ~= 'history_list' then openMenu(1)	
	else mp.commandv('script-message-to', 'uosc', 'close-menu') end
end


local function turnLast() -- 标记出本目录上次播放的视频
	local num = 0
	local playing_path = mp.get_property('path', '')
	for i = 1, #items do
		local item = items[i]
		if item.value[2]:gsub('\\[^\\]*$', '') == playing_path:gsub('\\[^\\]*$', '') then 
--			if item.icon ~= 'done' then
				num = i 
				break
--			end
		end
	end
	if num ~= 0 then
		items[num].icon = 'history'
		items[num].actions_place = 'outside'
		if not loaded and not from_mpv and o.last_video and items[num].value[2] ~= playing_path then openMenu(num) end
	end
end


local function playLastVideo() -- 继续播放上次的文件
	local v = mp.get_property_bool('idle-active', 'false')
	if v then
		from_mpv = true
		-- url:	1 播放进度	2 视频路径	3 音频路径	4 媒体标题
		-- 本地文件:	1 播放进度	2 视频路径
		mp.commandv('loadfile',items[1].value[2])
		seek_time = items[1].value[1]
		if items[1].value[3] ~= nil then
			http_audio_path = items[1].value[3]
			http_media_title = items[1].value[4]
		end
		mp.set_property('pause', 'no')
		mp.commandv('script-message-to', 'uosc', 'close-menu')
	elseif not v and o.space then
		mp.commandv('cycle', 'pause')
	end
end


local function preLog() -- 加载视频时先记录一部分日志(log_part), 结束播放时补充为完整的日志。因为time_pos只能在'end-file'时获取,而其他属性在'end-file'时获取不到,所以只能分两次记录。
	if o.log then
		local path = mp.get_property('path', '') 
		local system_time = string.format('[%s]', os.date('%Y-%m-%d %H:%M:%S'))
		local media_title = mp.get_property('media-title', '') 
		local duration = mp.get_property('duration', '')
		if path:sub(1,4) == 'http' then
			if o.log_url then
				local track_list = mp.get_property_native("track-list")
				local audio = 'null'
				for _, track in ipairs(track_list) do
					if track['type'] == 'audio' and track['external'] then
						audio = track['external-filename']
					end
				end
				log_part = {system_time, media_title, media_title, path, audio, media_title, 'url', duration}
			end
		else
			local file_name = mp.get_property('filename', '') 
			local upper_path = path:gsub('\\[^\\]*$', '')
			local parent_folder = path:gsub('\\[^\\]*$', ''):match('([^\\]+)$')
			local position_in_folder = findPosition(path)
			log_part = {system_time, media_title, file_name, path, upper_path, parent_folder, position_in_folder, duration}
		end
	end
end


local function writeLog() -- 写入日志
	if next(log_part) ~= nil then
		local text = string.format('%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n', log_part[1], log_part[2], log_part[3], log_part[4], log_part[5], log_part[6], log_part[7], time_pos, formatTime(time_pos), formatTime(log_part[8]), formatPercent(time_pos,log_part[8]))
		local file = io.open(o.log_path, 'a+')
		file:write(text)
		file:close()
	end
end


local function deleteLog(type, target) -- 删除日志条目
	local old_log = readLogFile()
	local new_log = {}
	
	if type == 'index' then
		table.remove(old_log, target)
		new_log = old_log
	elseif type == 'path' then
		for i, line in ipairs(old_log) do
			if line.path ~= target then
				table.insert(new_log,line)
			end
		end
	elseif type == 'upper_path' then
		for i, line in ipairs(old_log) do
			if line.upper_path ~= target then
				table.insert(new_log,line)
			end
		end
	elseif type == 'media_title' then
		for i, line in ipairs(old_log) do
			if line.media_title == target and line.position_in_folder == 'url' then
			else
				table.insert(new_log,line)
			end
		end
	end	
	local text = ''
	for i, line in ipairs(new_log) do
		text = text .. line.date_time .. ',' .. line.media_title .. ',' .. line.file_name .. ',' .. line.path .. ',' .. line.upper_path .. ',' .. line.parent_folder .. ',' .. line.position_in_folder .. ',' .. line.position_sec .. ',' .. line.position_for .. ',' .. line.duration_for .. ',' .. line.percent .. '\n'
	end
	local file = io.open(o.log_path, 'w')
	file:write(text)
	file:close()
end


mp.commandv('script-message-to', 'uosc', 'set-button', 'history', -- 添加 uosc 按钮
	utils.format_json({ icon = 'history', tooltip = t.tooltip, command = 'script-message toggle_history_menu', }))


mp.observe_property('idle-active', 'bool', function(_, v) -- mpv空闲时的行为
	if v and not loaded then
		if o.start_action == 'menu' then 
			getItems()
			toggleMenu()
		elseif o.start_action == 'resume' then
			getItems()
			if next(items) == nil then -- 没有记录时弹出提示
				openMenu(1)
			else
				from_mpv = true
				-- url:	1 播放进度	2 视频路径	3 音频路径	4 媒体标题
				-- 本地文件:	1 播放进度	2 视频路径
				mp.commandv('loadfile',items[1].value[2])
				seek_time = items[1].value[1]
				if items[1].value[3] ~= nil then
					http_media_title = items[1].value[4]
					http_audio_path = items[1].value[3]
				end
			end
		else getItems()
		end
	end
end)


mp.add_hook('on_unload', 9, function() -- 结束播放时获取播放进度
	time_pos = tonumber(string.format("%.2f", mp.get_property_number('time-pos') or 0))
end)


mp.register_event('file-loaded', function() -- 加载文件后的行为
	local path = mp.get_property('path', '') 
	if path:sub(1,4) == 'http' then
		mp.set_property_native('file-local-options/force-media-title',http_media_title)
		http_media_title = ''
	else
		if o.simplified_media_title then
			mp.set_property_native('file-local-options/force-media-title',simplifyTitle(mp.get_property('filename', '') ))
		end
	end
	if http_audio_path ~= 'null' then
		mp.commandv('audio-add', http_audio_path)
		http_audio_path = 'null'
	end
	if seek_time ~= '' then
		local t = tonumber(seek_time)
		if t >= 5 then
			seek_time = tostring(t - 5)
		else t = '0'
		end
		mp.commandv('seek', seek_time, 'absolute', 'exact')
		seek_time = ''
	end
	getItems()
	turnLast()
	preLog()
	loaded = true
	logable = true
end)


mp.register_event('end-file', function() -- 关闭文件后的行为
	if logable then
		writeLog()
		log_part = {}
		time_pos = 0
		getItems()
		logable = false
	end
end)


mp.add_key_binding(nil, 'toggle_history_menu', toggleMenu) -- 注册 开关菜单


mp.add_key_binding(nil, 'play_last_video', playLastVideo) -- 注册 继续播放


mp.add_key_binding(nil, 'clear_history', confirm) -- 注册 询问是否清空记录


mp.add_key_binding(nil, 'do_clear_history', clearHistory) -- 清空记录


mp.register_script_message('menu_event', function(json) -- 注册 菜单操作指令(删除记录,加载文件,切换过滤方式)
	local event = utils.parse_json(json)
--	event.type		'activate', 'move', 'search', 'key', 'paste', 'back', 'close'
--	event.action		item_actions中定义的
--	event.index		item的序号
--	event.value		item.value
--	event.menu_id		菜单id
--	event.is_pointer 	是否由鼠标触发
--	event.shift		是否按了shift
--	event.alt			是否按了alt
--	event.ctrl			是否按了ctrl
	if event.type == 'activate' then
		if event.action == 'delete' then
			if o.menu_filter == 'all' then 
				deleteLog('index', #items-event.index+1)
				table.remove(items, event.index)
				updateMenu(event.index)
			elseif o.menu_filter == 'deduplicated' then
				if event.value[3] == nil then
					deleteLog('path', event.value[2])
				else
					deleteLog('media_title', event.value[4])
				end
				table.remove(items, event.index)
				updateMenu(event.index)
			elseif o.menu_filter == 'folders' then
				if event.value[3] == nil then
					deleteLog('upper_path', event.value[2]:gsub('\\[^\\]*$', ''))
				else
					deleteLog('media_title', event.value[4])
				end
				table.remove(items, event.index)
				updateMenu(event.index)
			end
		else
			from_mpv = true
			-- url:	1 播放进度	2 视频路径	3 音频路径	4 媒体标题
			-- 本地文件:	1 播放进度	2 视频路径
			mp.commandv('loadfile', event.value[2])			
			seek_time = event.value[1]
			if event.value[3] ~= nil then
				http_media_title = event.value[4]
				http_audio_path = event.value[3]
			end
			mp.commandv('script-message-to', 'uosc', 'close-menu')
		end
	elseif event.type == 'key' then
--		event.type
--		event.key
--		event.selected_item.index
--		event.selected_item.value
--		event.id
--		event.menu_id
		if event.key == 'right' then
			if o.menu_filter == 'all' then
				o.menu_filter = 'deduplicated'
				getItems()
				turnLast()
				updateMenu(1)
			elseif o.menu_filter == 'deduplicated' then
				o.menu_filter = 'folders'
				getItems()
				turnLast()
				updateMenu(1)
			elseif o.menu_filter == 'folders' then
				o.menu_filter = 'all'
				getItems()
				turnLast()
				updateMenu(1)
			end
		elseif event.key == 'left' then
			if o.menu_filter == 'all' then
				o.menu_filter = 'folders'
				getItems()
				turnLast()
				updateMenu(1)
			elseif o.menu_filter == 'deduplicated' then
				o.menu_filter = 'all'
				getItems()
				turnLast()
				updateMenu(1)
			elseif o.menu_filter == 'folders' then
				o.menu_filter = 'deduplicated'
				getItems()
				turnLast()
				updateMenu(1)
			end
		end
	end
end)