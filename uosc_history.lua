local mp = require 'mp'
local utils = require 'mp.utils'
local o ={ 
	language = 'zh',
	start_action = 'menu',
	resume_in_folder = false,
	entries_number = true,
	log_path = '/:dir%mpvconf%/uosc_history.json',
}
(require 'mp.options').read_options(o)
if o.log_path:match('^/:dir%%mpvconf%%/') then 
	local dir, _ = utils.split_path(mp.find_config_file('.'))
	o.log_path = o.log_path:gsub('/:dir%%mpvconf%%/', dir)
elseif o.log_path:match('^/:dir%%script%%/') then
	local dir, _ = utils.split_path(mp.find_config_file('.'))
	o.log_path = o.log_path:gsub('/:dir%%script%%/', dir)
elseif o.log_path:match('^/:var%%(.*)%%') then
	local os_variable = o.log_path:match('/:var%%(.*)%%')
	o.log_path = o.log_path:gsub('/:var%%(.*)%%', os.getenv(os_variable))
end

if o.language == 'zh' then
	t = {
		del = '删除记录',
		title_all = '全部记录',
		title_dedup = '播放记录',
		title_folders = '文件夹记录',
		footnote = '← / → ：切换过滤方式   Ctrl+f：搜索记录',
		clear = '清空播放记录?',
		yes = '确定',
		no = '取消',
		tooltip = '播放记录',
		none = '暂无播放记录',
		resume_in_folder = '继续播放',
		now = '正在播放',
		log_enabled = '✔ 播放记录已启用',
		log_disabled = '✘ 播放记录已禁用',		
	}
else
	t = {
		del = 'Delete this record',
		title_all = 'All Records',
		title_dedup = 'Recent Media',
		title_folders = 'Recent Folders',
		footnote = 'Press ← / → to switch filter modes   Press Ctrl+F to search',
		clear = 'Clear Playback Records',
		yes = 'Yes',
		no = 'No',
		tooltip = 'Playback Records',
		none = 'No record',
		resume_in_folder = 'Resume Playback',
		now = 'Playing Now',
		log_enabled = '✔ Playback history logging enabled',
		log_disabled = '✘ Playback history logging disabled',
	}
end


local state ={
	resumable = false,
	loaded = false,
	logable = false,
	cleared = false,
	from_record = false,
	option_changed = false,
}

local entries, new, all, dedup, folders, value , options= {}, {}, {}, {}, {}, {}, {}


local function formatTime(sec)
	if sec then
		local s = tonumber(sec)
		local minutes = math.floor((s % 3600) / 60)
		local seconds = s % 60
		if s < 3600 then
			return string.format('%02d:%02d', minutes, seconds)		
		else
			return string.format('%d:%02d:%02d', math.floor(s / 3600), minutes, seconds)
		end	
	else
		return nil
	end
end


local function readLog()
	local file = io.open(o.log_path, 'r')
	if file then
		local a = utils.parse_json(file:read("*a"))
		 options, entries = a.options, a.entries
		file:close()
	end
end


local function writeLog()
	-- if not state.cleared then
	-- 	os.rename(o.log_path, o.log_path .. '.backup')
	-- end
	if options.log and next(new) then
		io.open(o.log_path, "w"):write('{"options":' .. utils.format_json(options) .. ',"entries":[' .. utils.format_json(new) .. ',' .. utils.format_json(entries):sub(2) .. '}'):close()
	else
		io.open(o.log_path, "w"):write('{"options":' .. utils.format_json(options) .. ',"entries":' .. utils.format_json(entries) .. '}'):close()
	end
	state.option_changed = false
	entries, all, dedup, folders = {}, {}, {}, {}
end


local function getItems()
	all, dedup, folders = {}, {}, {}
	if not next(entries) then
		local none = {{title = t.none, selectable = false, italic = true, align = 'center', muted = true}}
		all, dedup, folders = none, none, none	
	else
		local seen_path = {}
		local seen_upper_path = {}
		for i,entry in ipairs(entries) do
			if entry.url then
				table.insert(all, {
					title = entry.media_title,
					hint = entry.datetime,
					icon = '',
					value = {
						path = entry.path,
						pos = entry.pos,
						url = true,
						audio_path = entry.audio_path,
						media_title = entry.media_title,
					},
				})
				if not seen_path[entry.path] then
					table.insert(dedup,{						
						title = entry.media_title,
						hint = entry.progress,
						icon = '',
						value = {
							path = entry.path,
							pos = entry.pos,
							url = true,
							audio_path = entry.audio_path,
							media_title = entry.media_title,
							peers = {i},
						},
					})
					seen_path[entry.path] = #dedup
					all[i].dedup_index = #dedup -- for resumeInFolder()
				else
					table.insert(dedup[seen_path[entry.path]].value.peers, i)
					all[i].dedup_index = seen_path[entry.path] -- for resumeInFolder()
				end		
			else
				table.insert(all, {
					title = entry.media_title,
					hint = entry.datetime,
					icon = '',
					value = {
						path = entry.path,
						pos = entry.pos,
					},
				})
				if not seen_path[entry.path] then
					table.insert(dedup,{						
						title = entry.media_title,
						hint = entry.progress,
						icon = '',
						value = {
							path = entry.path,
							pos = entry.pos,
							peers = {i},
						},
					})					
					seen_path[entry.path] = #dedup
					all[i].dedup_index = #dedup -- for resumeInFolder()
					if not seen_upper_path[entry.upper_path] then
						table.insert(folders,{						
							title = entry.folder,
							hint = entry.pos_in_folder,
							icon = '',
							value = {
								path = entry.path,
								pos = entry.pos,
								peers = {i},
							},
						})
						seen_upper_path[entry.upper_path] = #folders
					else
						table.insert(folders[seen_upper_path[entry.upper_path]].value.peers, i)
					end
				else
					table.insert(dedup[seen_path[entry.path]].value.peers, i)
					table.insert(folders[seen_upper_path[entry.upper_path]].value.peers, i)
					all[i].dedup_index = seen_path[entry.path] -- for resumeInFolder()
				end
			end
		end
	end
end


local function clearConfirmed()
	entries = {}
	getItems()
	os.rename(o.log_path, o.log_path .. '.backup')
	io.open(o.log_path, "w"):write('[]'):close()
	state.cleared = true	
end


local function clearConfirm()
	local menu_props = {
		type = 'history',
		title = t.clear,
		items = {
			{title = t.yes, icon = 'done', align = 'center', bold = 'true', value = {'script-message-to', mp.get_script_name(), 'clear_confirmed'},}, 
			{title = t.no, icon = 'close', align = 'center', bold = 'true', value = {'ignore'},},
			},
		selected_index = 2,
		search_style = 'disabled',
	}
	mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json(menu_props))
end


local function resumeInFolder()
	if not next(all) then
		getItems()
	end
	for _,i in ipairs(folders) do
		local peer = i.value.peers[1]
		local entry = entries[peer]
		if new.upper_path == entry.upper_path and new.path ~= entry.path then
			mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json({
				title = t.resume_in_folder,
				selected_index = 2,
				items = {{
					title = new.media_title,
					hint = t.now,
					active = true,
					icon = '',
					},{
					title = entry.media_title,
					hint = entry.progress,
					icon = 'history',
					value = {
						path = entry.path,
						pos = entry.pos
					}}},
				callback = {mp.get_script_name(), 'menu_event'},
			}))
			local last_all = all[peer]
			last_all.icon = 'history'
			last_all.actions_place = 'outside'
			local last_dedup = dedup[last_all.dedup_index]
			last_dedup.icon = 'history'
			last_dedup.actions_place = 'outside'
			break
		end
	end
end


local function getNewEntry()
	new.media_title = mp.get_property('media-title', '')
	new.path = mp.get_property('path', '')
	if new.path:sub(1,4) == 'http' then
		new.url = true
		for _, track in ipairs(mp.get_property_native("track-list")) do
			if track['type'] == 'audio' and track['external'] then
				new.audio_path = track['external-filename']
			end
		end
	end
	if not new.url then
		local function getFolder(p)
			local a = utils.split_path(p)
			local b, c = utils.split_path(a:sub(1,-2))
			if c == '' then
				return a, a
			elseif not string.find(c, '^[Ss]eason[^%a%d]*%d+') then
				return a, c
			else
				local d, e = utils.split_path(b:sub(1,-2))
				if e == '' then
					return b, b
				else
					return b, string.format('%s  /  %s', e, c)
				end
			end
		end		
		local function findPosition(path)
			local upper_path, file_name = utils.split_path(path)
			local files = utils.readdir(upper_path, "files")
			local file_type = file_name:match(".+%.(%w+)$")
			local videos = {}
			for i, file in ipairs(files) do
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
		new.upper_path, new.folder = getFolder(new.path)
		if o.resume_in_folder and not state.loaded and not state.from_record and next(entries) then			
			resumeInFolder()
		end			
		new.pos_in_folder = findPosition(new.path)
	end
	new.datetime = os.date('%Y/%m/%d  %H:%M')
	new.progress = formatTime(mp.get_property('duration', ''))
end


local function openMenu(num,update)
	if not next(entries) then
		readLog()
		getItems()
	else
		if not next(all) then
			getItems()
		end		
	end
	local title, items
	if options.filter == 'all' then
		title = t.title_all .. ' (' .. tostring(#all) .. ')'
		items = all
	elseif options.filter == 'dedup' then
		title = t.title_dedup .. ' (' .. tostring(#dedup) .. ')'
		items = dedup
	else
		title = t.title_folders .. ' (' .. tostring(#folders) .. ')'
		items = folders
	end
	local menu_props = utils.format_json({
		type = 'history',
		title = title,
		selected_index = num,
		items = items,
		callback = {mp.get_script_name(), 'menu_event'},
		item_actions = {{name = 'delete', icon = 'delete', label = t.del}},
		footnote = t.footnote,
	})	
	if update then
		mp.commandv('script-message-to', 'uosc', 'update-menu', menu_props)
	else
		mp.commandv('script-message-to', 'uosc', 'open-menu', menu_props)
	end
end


local function toggleMenu()
	if mp.get_property_native('user-data/uosc/menu/type') ~= 'history' then
		openMenu(1)	
	else 
		mp.commandv('script-message-to', 'uosc', 'close-menu')
	end
end


local function resume()
	readLog()
	if entries then
		if next(entries) then
			mp.commandv('script-message-to', 'uosc', 'close-menu')
			value = {
				url = entries[1].url,
				pos = entries[1].pos,
				audio_path = entries[1].audio_path,
				media_title = entries[1].media_title
			}
			mp.commandv('loadfile', entries[1].path)
			mp.set_property('pause', 'no')
			state.from_record = true
		end		
	end
end


local function observePause()
	if mp.get_property_bool('idle-active', 'false') and state.resumable then
		resume()
	end
	state.resumable = true
end


local function deleteEntries(peers,menu_index)	
	if options.filter == 'all' then
		table.remove(entries, menu_index)
	else
		for i = #peers, 1, -1 do
			table.remove(entries, peers[i])
		end
	end
	getItems()
	openMenu(menu_index,true)
	if mp.get_property_bool('idle-active', 'false') then
		writeLog()
		readLog()
	end
end


local function toggleLog()
	if options.log then
		mp.osd_message(t.log_disabled)
		mp.msg.info(t.log_disabled)
		options.log = false
		new = {}
	else
		mp.osd_message(t.log_enabled)
		mp.msg.info(t.log_enabled)
		options.log = true
		if not next(new) and not mp.get_property_bool('idle-active', 'false') then
			getNewEntry()
		end
	end
	state.option_changed = true
end



mp.commandv('script-message-to', 'uosc', 'set-button', 'history',
	utils.format_json({
		icon = 'history',
		tooltip = t.tooltip,
		command = 'script-binding uosc_history/toggle_menu'
	})
)
	

if mp.get_property_bool('idle-active', 'false') then
	if o.start_action == 'menu' then 			
		toggleMenu()
	elseif o.start_action == 'resume' then
		resume()
	end
end


mp.observe_property('pause', 'bool', observePause)


mp.register_event('file-loaded', function()
	if value.audio_path then
		mp.commandv('audio-add', value.audio_path)
	end
	if value.pos then
		local seek_time = 0
		if value.pos >= 5 then
			seek_time = value.pos - 5
		end
		mp.commandv('seek', tostring(seek_time), 'absolute', 'exact')
	end
	if value.url then
		mp.set_property_native('file-local-options/force-media-title',value.media_title)
	end
	if not next(entries) then
		readLog()
	end
	if options.log then
		getNewEntry()
	end
	value = {}
	state.loaded = true
	state.logable = true
	state.from_record = false
	mp.unobserve_property(observePause)
end)


mp.add_hook('on_unload', 9, function()
	local pos = mp.get_property_number('time-pos') or 0
	if pos > 5 then
		new.pos = pos - 5
	else
		new.pos = 0
	end
	if new.progress then
		new.progress = formatTime(pos) .. ' / ' .. new.progress
	end
end)


mp.register_event('end-file', function()
	if state.logable then
		writeLog()
		state.logable = false
	end
	state.resumable = false
	mp.observe_property('pause', 'bool', observePause)
end)


mp.register_event('shutdown', function()
	if state.option_changed then 
		writeLog()
	end
end)


mp.add_key_binding(nil, 'toggle_menu', toggleMenu)


mp.add_key_binding(nil, 'toggle_log', toggleLog)


mp.add_key_binding(nil, 'clear', clearConfirm)

	
mp.register_script_message('clear_confirmed', clearConfirmed)


mp.register_script_message('menu_event', function(json)
	local event = utils.parse_json(json)
	if event.type == 'activate' then
		if event.action == 'delete' then
			deleteEntries(event.value.peers, event.index)
		elseif not event.action then
			value = event.value
			if value then
				mp.commandv('loadfile',value.path)
				state.from_record = true
			end
			mp.commandv('script-message-to', 'uosc', 'close-menu')
		end
	elseif event.type == 'key' then
		if event.key == 'right' then
			if options.filter == 'all' then options.filter = 'dedup'
			elseif options.filter == 'dedup' then options.filter = 'folders'
			else options.filter = 'all'
			end
			state.option_changed = true
		elseif event.key == 'left' then
			if options.filter == 'all' then options.filter = 'folders'
			elseif options.filter == 'dedup' then options.filter = 'all'
			else options.filter = 'dedup'
			end
			state.option_changed = true
		end
		openMenu(1,true)
	end
end)