-- https://github.com/Koopex/uosc_history_menu
-- version: 2.2.0
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
		title_bookmarks = '书签',	
		bookmark_add = '添加书签',
		bookmark_exists = '书签已存在',
		del_bookmark = '删除书签',
		rename_bookmark = '重命名',
		rename_bookmark_hint = '修改标题后回车',
		move_bookmark_up = '上移 (Ctrl+Up/PgUp/Home)',
		move_bookmark_down = '下移 (Ctrl+Down/PgDn/End)',
		footnote = '← / → ：切换过滤方式   Ctrl+f：搜索记录',
		clear_history = '清空播放记录?',
		clear_bookmarks = '清空书签?',
		yes = '确定',
		no = '取消',
		tooltip = '播放记录',
		resume_in_folder = '继续播放',
		now = '正在播放',
		log_enabled = '✔ 播放记录已启用',
		log_disabled = '✘ 播放记录已禁用',
		live = '直播',
		unknown = '未知',
	}
else
	t = {
		del = 'Delete this record',
		title_all = 'All Records',
		title_dedup = 'Recent Media',
		title_folders = 'Recent Folders',
		title_bookmarks = 'Bookmarks',
		bookmark_add = 'Add Bookmark',
		bookmark_exists = 'Bookmark already exists',
		del_bookmark = 'Delete Bookmark',
		rename_bookmark = 'Rename',
		rename_bookmark_hint = 'Type new title and press Enter',
		move_bookmark_up = 'Move Up (Ctrl+Up/PgUp/Home)',
		move_bookmark_down = 'Move Down (Ctrl+Down/PgDn/End)',
		footnote = 'Press ← / → to switch filter modes   Press Ctrl+F to search',
		clear_history = 'Clear Playback History',
		clear_bookmarks = 'Clear Bookmarks',
		yes = 'Yes',
		no = 'No',
		tooltip = 'Playback Records',
		resume_in_folder = 'Resume Playback',
		now = 'Playing Now',
		log_enabled = '✔ Playback history logging enabled',
		log_disabled = '✘ Playback history logging disabled',
		live = 'Live',
		unknown = 'Unknown',
	}
end


local state ={
	read = false,
	resumable = false,
	loaded = false,
	logable = false,
	from_record = false,
	option_changed = false,
}

local options, entries, new, all, dedup, folders, value , bookmarks, pending_rename_index , clear_type = {log = true, filter = 'dedup'}, {}, {}, {}, {}, {}, {}, {}, nil, nil


local function formatTime(s)
	if s then
		local minutes = math.floor((s % 3600) / 60)
		local seconds = s % 60
		if s < 3600 then
			return string.format('%02d:%02d', minutes, seconds)		
		else
			return string.format('%d:%02d:%02d', math.floor(s / 3600), minutes, seconds)
		end	
	else
		return t.unknown
	end
end


local function readLog()
	state.read = true
	local file = io.open(o.log_path, 'r')
	if file then
		local a = utils.parse_json(file:read("*a"))
		 options, entries, bookmarks = a.options, a.entries, a.bookmarks
		file:close()
	end
end


local function writeLog()
	if options.log and next(new) then
		io.open(o.log_path, "w"):write('{"options":' .. utils.format_json(options) .. ',"bookmarks":' .. utils.format_json(bookmarks) .. ',"entries":[' .. utils.format_json(new) .. ',' .. utils.format_json(entries):sub(2) .. '}'):close()
		new = {}
	else
		io.open(o.log_path, "w"):write('{"options":' .. utils.format_json(options) .. ',"bookmarks":' .. utils.format_json(bookmarks) .. ',"entries":' .. utils.format_json(entries) .. '}'):close()
	end
	state.option_changed = false
	all, dedup, folders = {}, {}, {}
end


local function getItems()
	all, dedup, folders = {}, {}, {}
	if not next(entries) then
		return
	else
		local seen_path = {}
		local seen_upper_path = {}
		for i,entry in ipairs(entries) do
			if entry.url then
				table.insert(all, {
					title = entry.media_title,
					hint = entry.datetime,
					-- icon = '',
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
						-- icon =  '',
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
					-- icon =  '',
					value = {
						path = entry.path,
						pos = entry.pos,
					},
				})
				if not seen_path[entry.path] then
					table.insert(dedup,{						
						title = entry.media_title,
						hint = entry.progress,
						-- icon =  '',
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
							-- icon =  '',
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
	if clear_type == 'history' then
		entries = {}
	elseif clear_type == 'bookmarks' then
		bookmarks = {}
	end
	getItems()
	writeLog()
end


local function clearHistory()
	clear_type = 'history'
	local menu_props = {
		type = 'history',
		title = t.clear_history,
		items = {
			{title = t.yes, icon = 'done', align = 'center', bold = 'true', value = {'script-message-to', mp.get_script_name(), 'clear_confirmed'},}, 
			{title = t.no, icon = 'close', align = 'center', bold = 'true', value = {'ignore'},},
			},
		selected_index = 2,
		search_style = 'disabled',
	}
	mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json(menu_props))
end


local function clearBookmarks()
	clear_type = 'bookmarks'
	local menu_props = {
		type = 'history',
		title = t.clear_bookmarks,
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
	new.datetime = os.date('%Y/%m/%d  %H:%M')
	new.path = mp.get_property('path', '')
	local dur = mp.get_property_number('duration', 0)
	if new.path:match("^http") or new.path:match("^rtmp") then
		new.url = true
		local found_referer = false
		local headers = mp.get_property('options/http-header-fields', '')
		if headers ~= '' then
			for part in string.gmatch(headers, '([^,]+)') do
				if type(part) == 'string' then
					local key, value = part:match("^%s*(.-)%s*:%s*(.-)%s*$")
					if key and value and key:lower():match("^referer$") and value:match("^http") then
						new.path = value
						found_referer = true
						break
					end
				end
			end
		end
		if not found_referer then
			for _, track in ipairs(mp.get_property_native("track-list")) do
				if track['type'] == 'audio' and track['external'] then
					new.audio_path = track['external-filename']
				end
			end
		end
		mp.add_timeout(1, function()
			if dur == mp.get_property_number('duration', 0) then
				new.progress = formatTime(dur)
			else
				new.progress = t.live
			end
		end)
	else
		local function getFolder(p)
			local upper_p1 = utils.split_path(p)
			local upper_p2, parent_d1 = utils.split_path(upper_p1:sub(1,-2))
			if parent_d1 == '' then
				return upper_p1, upper_p1
			elseif not string.find(parent_d1, '^[Ss]eason[^%a%d]*%d+') then
				return upper_p1, parent_d1
			else
				local upper_p3, parent_d2 = utils.split_path(upper_p2:sub(1,-2))
				if parent_d2 == '' then
					return upper_p2, string.format('%s / %s', upper_p2, parent_d1)
				else
					return upper_p2, string.format('%s / %s', parent_d2, parent_d1)
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
		new.progress = formatTime(dur)
	end
end


local function openMenu(num, update, bookmarks_only)
	if not state.read then
		readLog()
		getItems()
	else
		if not next(all) then
			getItems()
		end		
	end
	local title, items
	local item_actions = {{name = 'mark', icon = 'star', label = t.bookmark_add},{name = 'delete', icon = 'delete', label = t.del},}
	local type = 'history'
	if bookmarks_only then
		type = 'bookmarks'
		title = t.title_bookmarks .. ' (' .. tostring(#bookmarks) .. ')'
		items = bookmarks
		item_actions = {
			{name = 'rename', icon = 'edit', label = t.rename_bookmark},
			-- {
			-- 	name = 'move_up',
			-- 	icon = 'arrow_upward',
			-- 	label = t.move_bookmark_up,
			-- 	filter_hidden = true,
			-- },{
			-- 	name = 'move_down',
			-- 	icon = 'arrow_downward',
			-- 	label = t.move_bookmark_down,
			-- 	filter_hidden = true,
			-- },				
			{name = 'delete', icon = 'delete', label = t.del_bookmark}
		}
	elseif options.filter == 'all' then
		title = t.title_all .. ' (' .. tostring(#all) .. ')'
		items = all
	elseif options.filter == 'dedup' then
		title = t.title_dedup .. ' (' .. tostring(#dedup) .. ')'
		items = dedup
	elseif options.filter == 'folders' then
		title = t.title_folders .. ' (' .. tostring(#folders) .. ')'
		items = folders
	end
	local menu_props = {
		type = type,
		title = title,
		selected_index = num,
		items = items,
		callback = {mp.get_script_name(), 'menu_event'},
		item_actions = item_actions,
		footnote = t.footnote,
	}
	if bookmarks_only then
    	menu_props.on_move = 'callback'
		menu_props.id = 'bookmarks'
		-- menu_props.item_actions_place = 'outside'
		menu_props.footnote = t.move_bookmark_up .. '   ' .. t.move_bookmark_down
	end
	if update then
		mp.commandv('script-message-to', 'uosc', 'update-menu', utils.format_json(menu_props))
	else
		mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json(menu_props))
	end
end


local function toggleMenu()
	if mp.get_property_native('user-data/uosc/menu/type') ~= 'history' then
		openMenu(1)	
	else 
		mp.commandv('script-message-to', 'uosc', 'close-menu')
	end
end


local function toggleBookmarks()
	if mp.get_property_native('user-data/uosc/menu/type') ~= 'bookmarks' then
		openMenu(1, false, true)	
	else 
		mp.commandv('script-message-to', 'uosc', 'close-menu')
	end
end


local function addBookmarks()
	if mp.get_property_bool('idle-active', 'false') then
		return
	else
		local path = mp.get_property('path', '')
		for _, bookmark in ipairs(bookmarks) do
			if bookmark.value.path == path then
				mp.osd_message(t.bookmark_exists)
				return
			end
		end
		local item = {
			title = mp.get_property('media-title', ''),
			value = {path = path},
		}
		table.insert(bookmarks, item)
		mp.osd_message(t.bookmark_add)
		state.option_changed = true
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


local function deleteEntries(peers, menu_index)
	if mp.get_property_native('user-data/uosc/menu/type') == 'bookmarks' then
		table.remove(bookmarks, menu_index)
		openMenu(menu_index, true, true)
	else
		if options.filter == 'all' then
			table.remove(entries, menu_index)
		else
			for i = #peers, 1, -1 do
				table.remove(entries, peers[i])
			end
		end
		getItems()
		openMenu(menu_index,true)
	end
	if mp.get_property_bool('idle-active', 'false') then
		state.option_changed = true
	end
end


local function enableHistory()
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


local function moveBookmark(from_index, to_index)
	if from_index < 1 or from_index > #bookmarks or to_index < 1 or to_index > #bookmarks then
		return
	end
	local item = table.remove(bookmarks, from_index)
	table.insert(bookmarks, to_index, item)
	openMenu(to_index, true, true)
	state.option_changed = true
end


local function menu_event(json)
	local event = utils.parse_json(json)
	if event.type == 'activate' then
		if event.action == 'delete' then
			deleteEntries(event.value.peers, event.index)
		elseif event.action == 'mark' then
			for _, bookmark in ipairs(bookmarks) do
				if bookmark.value.path == event.value.path then
					mp.osd_message(t.bookmark_exists)
					return
				end
			end
			local title
			if options.filter == 'all' then
				title = entries[event.index].media_title
			else
				title = entries[event.value.peers[1]].media_title
			end
			local item = {
				title = title,
				value = {path = event.value.path},
			}
			table.insert(bookmarks, item)
			state.option_changed = true
			mp.osd_message(t.bookmark_add)
		elseif event.action == 'move_up' or event.action == 'move_down' then
			local to_index = event.index + (event.action == 'move_up' and -1 or 1)
				moveBookmark(event.index, to_index)
		elseif event.action == 'rename' then
			pending_rename_index = event.index
			menu_props = {
				id = 'rename_bookmark',
				title = '',
				callback = {mp.get_script_name(), 'menu_event'},
				on_search = 'callback',
				search_style = 'palette',
				search_debounce = 'submit',
				items = {{
					title = t.rename_bookmark_hint,
					selectable = false, 
					italic = true,
					muted = true,
					align = 'right',
				}},
			}
			local title = bookmarks[pending_rename_index].title
			mp.osd_message(string.len(title))
			if string.len(title) < 150 then
				menu_props.search_suggestion = title
			end
			mp.commandv('script-message-to', 'uosc', 'open-menu',  utils.format_json(menu_props))
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
			-- else options.filter = 'all'
			end
			state.option_changed = true
		elseif event.key == 'left' then
			if options.filter == 'folders' then options.filter = 'dedup'
			elseif options.filter == 'dedup' then options.filter = 'all'
			-- else options.filter = 'folders'
			end
			state.option_changed = true
		end
		openMenu(1,true)
	elseif event.type == 'move' then
		moveBookmark(event.from_index, event.to_index)
	elseif event.type == 'search' and event.menu_id == 'rename_bookmark' and pending_rename_index then
		if pending_rename_index and event.query and event.query ~= '' then
			bookmarks[pending_rename_index].title = event.query
			openMenu(pending_rename_index, false, true)
			pending_rename_index = nil
			state.option_changed = true
		end
	end
end


mp.commandv('script-message-to', 'uosc', 'set-button', 'history',
	utils.format_json({
		icon = 'history',
		tooltip = t.tooltip,
		command = 'script-binding uosc_history/history'
	})
)


mp.commandv('script-message-to', 'uosc', 'set-button', 'bookmarks',
	utils.format_json({
		icon = 'bookmarks',
		tooltip = t.title_bookmarks,
		command = 'script-binding uosc_history/bookmarks'
	})
)


mp.commandv('script-message-to', 'uosc', 'set-button', 'add_bookmarks',
	utils.format_json({
		icon = 'star',
		tooltip = t.bookmark_add,
		command = 'script-binding uosc_history/add_bookmarks'
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
	if pos >= 3 then
		new.pos = pos - 3
	end
	if new.progress then
		new.progress = formatTime(pos) .. ' / ' .. new.progress
	end
end)


mp.register_event('end-file', function()
	if state.logable then
		writeLog()
		if mp.get_property_bool('idle-active', 'false') then
			readLog()
		end
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


mp.add_key_binding(nil, 'history', toggleMenu)
mp.add_key_binding(nil, 'enable_history', enableHistory)
mp.add_key_binding(nil, 'clear_history', clearHistory)
mp.add_key_binding(nil, 'bookmarks', toggleBookmarks)
mp.add_key_binding(nil, 'add_bookmarks', addBookmarks)
mp.add_key_binding(nil, 'clear_bookmarks', clearBookmarks)
mp.register_script_message('clear_confirmed', clearConfirmed)
mp.register_script_message('menu_event', function(json)menu_event(json)end)