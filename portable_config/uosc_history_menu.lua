local mp = require 'mp'
local utils = require 'mp.utils'
local o ={ 
	log_path = '/:dir%mpvconf%/_cache/uosc_history_menu.log' ,
	menu_filter = 'all',	
	item_type = 'file',
	remove_duplicates = true,
	last_vedio = true,
	simplified_media_title = false,
	show_playing = false,
	start_action = 'menu',
	blocked_words = 'Netflix,AMZN,Disney%+,Bilibili,YUV420P10,Multi%-Audio,1920x1080,Blu%-ray,ULTRAHD,2Audio,3Audio,4Audio,BluRay,bluray,WEB%-DL,TrueHD,DTS%-HD,REPACK,Atmos,BDrip,10bit,60FPS,60fps,H%.264,1080p,1080P,2160p,2160P,720P,720p,DoVi,IMAX,HDTV,x265,X265,H265,x264,X264,H264,HEVC,VC%-1,FLAC,DIY,EUR,DDP,DTS,HDR,UHD,AVC,AAC,AC3,4K,2%.0,5%.1,7%.1,DV,DD,HQ,MA',
	hint = 'date',
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


local pre_logable = true -- 记录前半部分日志的开关, 防止重复记录, 只有关闭文件后和加载完文件前可以记录前半部分日志
local loaded = false -- 记录是否加载过文件, 用来区分两种空闲状态: 加载文件前和关闭文件后
local logable = false -- 写日志开关, 防止重复写日志
local menu_showing = false -- 记录菜单的状态来切换开闭
local time_pos = 0 -- 关闭文件时记录的播放进度(秒)
local duration = 0 -- 关闭文件时记录的视频时长(秒)
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

local function findPosition(path) -- 找到视频在文件夹中的排序
	local upper_path, file_name = utils.split_path(path)
	local entries = utils.readdir(upper_path, "files")
	local file_type = file_name:match(".+%.(%w+)$")
	local vedios = {}
	for i, file in ipairs(entries) do
		if file:match(".+%.(%w+)$") == file_type then
			table.insert(vedios, file)
		end
	end
	table.sort(vedios)
	local a = 0
	for i, v in ipairs(vedios) do
		if v == file_name then
			a = i
		end
	end
	return string.format('%d / %d', a, #vedios)
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

local function preLog() -- 加载视频时先记录一部分日志(log_part), 结束播放时获取到完整的日志再补充完整
	local system_time = string.format('[%s]', os.date('%Y-%m-%d %H:%M:%S'))
	local media_title = mp.get_property('media-title', '') 
	local file_name = mp.get_property('filename', '') 
	local path = mp.get_property('path', '') 
	if path:sub(1,4) ~= 'http' then
		local upper_path = path:gsub('\\[^\\]*$', '')
		local parent_folder = path:gsub('\\[^\\]*$', ''):match('([^\\]+)$') -- 菜单过滤方式为目录时, 显示的文件夹名, 中间再加一个:gsub('\\[^\\]*$', '')可以显示再上一级的文件夹名
		local position_in_folder = findPosition(path)	
		log_part = {system_time, media_title, file_name, path, upper_path, parent_folder, position_in_folder}
	end
end

local function writeLog(position, length) -- 获取到结束播放时的进度和视频时长, 写入完整的日志
	if next(log_part) ~= nil then
		local text = string.format('%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n', log_part[1], log_part[2], log_part[3], log_part[4], log_part[5], log_part[6], log_part[7], position, formatTime(position), formatTime(length), formatPercent(position,length))
		local file = io.open(o.log_path, 'a+')
	file:write(text)
	file:close()
	end
end

local function readLogFile() -- 读日志, 转为table
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

local function removeDuplicates() -- 去除重复记录并倒序排列
	local arr = readLogFile()	
	if log_part[2] ~= nil and o.show_playing then
		table.insert(arr, {
			date_time = log_part[1],
			media_title = log_part[2],
			file_name = log_part[3],
			path = log_part[4],
			upper_path = log_part[5],
			parent_folder = log_part[6], 
			position_in_folder =log_part[7],})
	end
	local seen = {}
	local result = {}
	if next(arr) ~= nill then
		if o.menu_filter == 'dic' then
			if arr[#arr].position_sec == nil then
				table.insert(result, arr[#arr])
				for i = #arr - 1, 1, -1 do
					local v = arr[i]
					local x = v.upper_path
					if not seen[x] then
						table.insert(result, v)
						seen[x] = true
					end
				end		
			else
				for i = #arr, 1, -1 do
					local v = arr[i]
					local x = v.upper_path
					if not seen[x] then
						table.insert(result, v)
						seen[x] = true
					end
				end
			end	
		elseif o.menu_filter == 'dry' then
			if arr[#arr].position_sec == nil then
				table.insert(result, arr[#arr])
				for i = #arr - 1, 1, -1 do
					local v = arr[i]
					local x = v.path
					if not seen[x] then
						table.insert(result, v)
						seen[x] = true
					end
				end						
			else
				for i = #arr, 1, -1 do
					local v = arr[i]
					local x = v.path
					if not seen[x] then
						table.insert(result, v)
						seen[x] = true
					end
				end
			end
		elseif o.menu_filter == 'all' then
			for i = #arr, 1, -1 do
				local v = arr[i]
				table.insert(result, v)
			end	
		end
	end
	return result
end

local function getItems()	-- 根据需要从日志条目提取内容用来构建菜单条目
	local entries = removeDuplicates()
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
		if o.menu_filter ~= 'dic' then title = arr.media_title			
		else
			if o.simplified_media_title then
				title = '/' .. simplifyTitle(arr.parent_folder) .. '/'
			else 	title = '/' .. arr.parent_folder .. '/' end
		end
		local hint = ''
		local icon = ''
		local actions = {{name = 'delete', icon = 'delete', label = '删除该记录：点击按钮 / 按下“Delete”'},}
		local active = false
		if arr.position_for ~= nil then
			if o.menu_filter ~= 'dic' then			
				if o.hint == 'date' then hint = arr.date_time:sub(7, -5)
				elseif o.hint == 'position' then hint = arr.position_for
				elseif o.hint == 'duration' then hint = arr.duration_for
				elseif o.hint == 'percent' then hint = arr.percent
				elseif o.hint == 'position+duration' then hint = string.format('%s / %s', arr.position_for, arr.duration_for) 
				elseif o.hint == 'percent+duration' then hint = string.format('%s  %s', arr.percent, arr.duration_for)
				end
			else  hint = arr.position_in_folder end
		else
			if o.menu_filter == 'dic' then hint = arr.position_in_folder icon = 'done' active = 1 actions = {}
			else hint = '正在播放' icon = 'done' active = 1 actions = {} end	
		end	
		table.insert(result, {title = title, hint = hint, value = { 'loadfile',arr.path}, icon = icon, upper_path = arr.upper_path, active = active, actions = actions, })
	end
	items = result
end

local function openHistoryMenu(num) -- 根据获取到的菜单条目创建菜单
	local menu_props = {}
	local menu_title = ''
	if o.menu_filter == 'all' then menu_title = '播放记录（全部）'
	elseif o.menu_filter == 'dry' then menu_title = '播放记录（去重）'
	elseif o.menu_filter == 'dic' then menu_title = '播放记录（目录）' end
	if next(items) == nil then
		menu_props = {type = 'history_list', title = '播放记录', search_style = 'disabled', footnote = '播放任意视频进行记录',
		items = {{title = '暂无播放记录', hint = '', value = {}, selectable = false, align = 'center',italic = true, }, }, }
	else 	menu_props = {type = 'history_list', title = menu_title, selected_index = num, callback = {mp.get_script_name(), 'menu-event'},items = items, footnote = '播放:ENTER   切换过滤方式:← / →   搜索记录:Ctrl+f 或 \\',}
	end	
	mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json(menu_props))
end

local function updateHistoryMenu(num) -- 更新菜单(删除记录后使用)
	local menu_props = {}
	local menu_title = ''
	if o.menu_filter == 'all' then menu_title = '播放记录（全部）'
	elseif o.menu_filter == 'dry' then menu_title = '播放记录（去重）'
	elseif o.menu_filter == 'dic' then menu_title = '播放记录（目录）' end
	if next(items) == nil then
		menu_props = {type = 'history_list', title = '播放记录', search_style = 'disabled', footnote = '播放任意视频进行记录',
		items = {{title = '暂无播放记录', hint = '', value = {}, selectable = false, align = 'center',italic = true, }, }, }
	else 	menu_props = {type = 'history_list', title = menu_title, selected_index = num, callback = {mp.get_script_name(), 'menu-event'},items = items, footnote = '播放:ENTER   切换过滤方式:← / →   搜索记录:Ctrl+f 或 \\',}
	end	
	mp.commandv('script-message-to', 'uosc', 'update-menu', utils.format_json(menu_props))
end

local function toggleHistoryMenu() -- 开关菜单
	local menu_type = mp.get_property_native('user-data/uosc/menu/type')
	if menu_type ~= 'history_list' then openHistoryMenu(1)	
	else mp.commandv('script-message-to', 'uosc', 'close-menu') end
end

local function turnLast() -- 寻找本目录上次播放的视频
	local num = 0
	for i = 1, #items do
		local item = items[i]
		if item.upper_path == log_part[5] then 
			if item.icon ~= 'done' then
				num = i 
				break
			end
		end
	end
	if num ~= 0 and items[num].value[2] ~= log_part[4] then
		items[num].icon = 'history'
		items[num].actions_place = 'outside'
		if not loaded and o.last_vedio then openHistoryMenu(num) end
	end
end

local function deleteLog(type, target) -- 删除日志条目, 根据不同的type筛选
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
	end	
	local text = ''
	for i, line in ipairs(new_log) do
		text = text .. line.date_time .. ',' .. line.media_title .. ',' .. line.file_name .. ',' .. line.path .. ',' .. line.upper_path .. ',' .. line.parent_folder .. ',' .. line.position_in_folder .. ',' .. line.position_sec .. ',' .. line.position_for .. ',' .. line.duration_for .. ',' .. line.percent .. '\n'
	end
	local file = io.open(o.log_path, 'w')
	file:write(text)
	file:close()
end



mp.observe_property('idle-active', 'bool', function(_, v) -- mpv空闲时的行为
	if v and not loaded then
		if o.start_action == 'menu' then 
			getItems()
			toggleHistoryMenu()
		elseif o.start_action == 'resume' then
			getItems()
			if next(items) == nil then				
				toggleHistoryMenu()
			else	mp.commandv('loadfile',items[1].value[2]) end
		else getItems()
		end
	end
end)

mp.add_hook('on_unload', 9, function() -- 结束播放时获取播放进度和视频长度
	time_pos = (mp.get_property_number('time-pos') or 0)
	duration = mp.get_property('duration', '') 
end)

mp.register_event('start-file', function()  -- 加载文件前的行为: 记录一部分日志, 获取一次菜单条目, 寻找同目录上次播放的文件
	if o.simplified_media_title then
		local file_name = mp.get_property('filename', '') 
		mp.set_property_native('file-local-options/force-media-title',simplifyTitle(file_name))
	end	
	if pre_logable then
		preLog() 
		pre_logable = false
		getItems()
		mp.commandv('script-message-to', 'uosc', 'close-menu')
		turnLast()
	end
end)

mp.register_event('file-loaded', function() -- 加载文件后的行为: 切换一些开关, 防止'start-file'和'end-file'关联的行动重复运行
	loaded = true
	logable = true
	pre_logable = true
end)

mp.register_event('end-file', function() -- 关闭文件后的行为: 记录一条日志, 切换开关, 清空log_part为下一次加载做准备
	if logable then
		writeLog(time_pos, duration)
		time_pos = 0
		duration = 0
		logable = false
		log_part = {} 
		getItems()
	end
end)

mp.commandv('script-message-to', 'uosc', 'set-button', 'history', -- 添加uosc 按钮
	utils.format_json({ icon = 'history', tooltip = '播放记录', command = 'script-message toggle_history_menu', }))

mp.register_script_message('toggle_history_menu', toggleHistoryMenu) -- 注册开关菜单命令

mp.register_script_message('menu-event', function(json) -- 处理菜单返回来的指令(删除记录或者加载文件)
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
				updateHistoryMenu(event.index)
			elseif o.menu_filter == 'dry' then
				deleteLog('path', event.value[2])
				table.remove(items, event.index)
				updateHistoryMenu(event.index)
			elseif o.menu_filter == 'dic' then
				deleteLog('upper_path', event.value[2]:gsub('\\[^\\]*$', ''))
				table.remove(items, event.index)
				updateHistoryMenu(event.index)
			end
		else
			mp.commandv(event.value[1], event.value[2])
		end
	elseif event.type == 'key' then
--		event.type
--		event.key
--		event.selected_item.index
--		event.selected_item.value
--		event.id
--		event.menu_id
		if event.key == 'del' then
			if o.menu_filter == 'all' then  
				deleteLog('index', #items-event.selected_item.index+1)
				table.remove(items, event.selected_item.index)
				updateHistoryMenu(event.selected_item.index)
			elseif o.menu_filter == 'dry' then
					deleteLog('path', event.selected_item.value[2])
					table.remove(items, event.selected_item.index)
					updateHistoryMenu(event.selected_item.index)
			elseif o.menu_filter == 'dic' then
				deleteLog('upper_path', event.selected_item.value[2]:gsub('\\[^\\]*$', ''))
				table.remove(items, event.selected_item.index)
				updateHistoryMenu(event.selected_item.index)
			end
		elseif event.key == 'right' then
			if o.menu_filter == 'all' then
				o.menu_filter = 'dry'
				getItems()
				turnLast()
				openHistoryMenu(1)
			elseif o.menu_filter == 'dry' then
				o.menu_filter = 'dic'
				getItems()
				turnLast()
				openHistoryMenu(1)
			elseif o.menu_filter == 'dic' then
				o.menu_filter = 'all'
				getItems()
				turnLast()
				openHistoryMenu(1)
			end
		elseif event.key == 'left' then
			if o.menu_filter == 'all' then
				o.menu_filter = 'dic'
				getItems()
				turnLast()
				openHistoryMenu(1)
			elseif o.menu_filter == 'dry' then
				o.menu_filter = 'all'
				getItems()
				turnLast()
				openHistoryMenu(1)
			elseif o.menu_filter == 'dic' then
				o.menu_filter = 'dry'
				getItems()
				turnLast()
				openHistoryMenu(1)
			end
		end
	end
end)

mp.register_script_message('clear_history', function() -- 清空播放记录并打开空菜单提示已清空
	io.open(o.log_path, 'w'):close() 
	log_part = {} 
	if logable then preLog() end 
	getItems() 
	openHistoryMenu(1)
end)