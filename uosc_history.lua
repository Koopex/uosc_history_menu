-- https://github.com/Koopex/uosc_history_menu
-- version: 2.3.1

--=================================[ 脚本设置 | Script Settings ]===================================
local o ={ 
	-- <zh>: 中文
	-- <en>: English
	language = 'zh',

	--------[ 打开mpv以后的动作 | Startup Action ]--------
	-- <resume>	恢复上次播放的文件	| Play the last media
	-- <menu>	打开播放记录		| Open history menu
	-- <none>	什么也不做			| None
	start_action = 'none',

	--------[ 文件夹续播 | Resume in Same Folder ]--------
	--[[当你打开某文件夹中的一个视频时，如果同文件夹内有其他视频记录，插件会弹出菜单询问你是否跳转续播]]
	--[[ When you open a video in a folder, if there are other video records in the same folder, 
	the script will pop up a menu asking if you want to jump to resume playback.]]
	-- <true>
	-- <false>
	resume_in_folder = false,

	--------------[ 条目标题 | Entry Title ]---------------
	-- <true>	文件名		| Filename
	-- <false>	媒体标题	| Media title
	filename = false,

	--------------[ 记录文件路径 | Log path ]--------------
	-- ~~home 表示mpv.conf所在文件夹
	-- ~~home is the mpv config directory
	log_path = '~~home/uosc_history.json',
}--[[ 
--------------------------------------[ 快捷键 |  Shortcuts ]--------------------------------------
e			script-binding uosc_history/bookmarks	        #! 收藏夹			| Bookmarks			
Ctrl+e		script-binding uosc_history/add_bookmarks		#! 添加收藏			| Add Bookmarks				
Ctrl+Alt+e	script-binding uosc_history/clear_bookmarks		#! 清空收藏夹	    | Clear Bookmarks			
r			script-binding uosc_history/history	            #! 播放记录         | Playback History            
Ctrl+r		script-binding uosc_history/enable_history      #! 禁用 播放记录	| Disable History												
Ctrl+Alt+r  script-binding uosc_history/clear_history	    #! 清空播放记录		| Clear History
---------------------------------------------------------------------------------------------------

--------------[ uosc按钮 | uosc Buttons ]--------------
button:history			播放记录	| Playback History											
button:bookmarks		收藏夹		| Bookmarks
button:add_bookmarks	添加收藏	| Add Bookmarks
-------------------------------------------------------
====================================================================================================]]

local mp = require 'mp'
local utils = require 'mp.utils'
local platform = mp.get_property_native('platform')
local script_name = mp.get_script_name()
require 'mp.options'.read_options(o, script_name)

if o.log_path:match('^/:dir%%mpvconf%%') or o.log_path:match('^~~home') then
	o.log_path = o.log_path:gsub('^/:dir%%mpvconf%%', '~~home')
	o.log_path = mp.command_native({"expand-path", o.log_path})
end


local t = o.language == 'zh' and {
	del = '删除记录',
	title_all = '全部记录',
	title_dedup = '播放记录',
	title_folders = '文件夹记录',
	title_bookmarks = '收藏夹',	
	old_bookmarks = '原收藏夹',
	bookmark_add = '收藏',
	added = '已添加',
	select_folder = '选择收藏夹',
	change_folder = '移动到其他收藏夹',
	create_bookmark_folder = '新建收藏夹',
	create_folder_tip = '输入后回车创建新收藏夹',
	edit_bookmark_folder = '编辑收藏夹',
	bookmark_exists = '已经收藏过了',
	del_bookmark = '删除',
	rename_bookmark = '重命名',
	rename_bookmark_hint = '修改标题后回车',
	delete_key = '删除 (Del)',
	rename_folders = '重命名 (←)',
	rename_bookmarks = '重命名 (→)',
	move_bookmark_up = '上移 (Ctrl+Up/PgUp/Home)',
	move_bookmark_down = '下移 (Ctrl+Down/PgDn/End)',
	footnote = '← / → ：切换过滤方式   Ctrl+f：搜索记录',
	clear_history = '清空播放记录?',
	clear_bookmarks = '清空收藏夹?',
	yes = '确定',
	no = '取消',
	tooltip = '播放记录',
	resume_in_folder = '继续播放',
	now = '正在播放',
	log_enabled = '播放记录: 启用',
	log_disabled = '播放记录: 禁用',
	live = '直播',
	unknown = '未知', 
	} or {
	del = 'Delete this record',
	title_all = 'All Records',
	title_dedup = 'Recent Media',
	title_folders = 'Recent Folders',
	title_bookmarks = 'Bookmarks',
	old_bookmarks = 'Old Bookmarks',
	bookmark_add = 'Add Bookmark',
	added = 'Added',
	select_folder = 'Select Bookmark Group',
	change_folder = 'Change group',
	create_bookmark_folder = 'Create a new group',
	create_folder_tip = 'Type and press Enter to create',
	edit_bookmark_folder = 'Edit groups',
	bookmark_exists = 'Bookmark already exists',
	del_bookmark = 'Delete Bookmark',
	rename_bookmark = 'Rename',
	rename_bookmark_hint = 'Type new title and press Enter',
	delete_key = 'Delete (Del)',
	rename_folders = 'Rename (←)',
	rename_bookmarks = 'Rename (→)',
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
	log_enabled = 'Playback history logging enabled',
	log_disabled = 'Playback history logging disabled',
	live = 'Live',
	unknown = 'Unknown',
}

local buttons = {
	{
		name = 'history',
		value = {
			icon = 'history',
			tooltip = t.tooltip,
			command = 'script-binding uosc_history/history'
		}
	},
	{
		name = 'bookmarks',
		value = {
			icon = 'folder_special',
			tooltip = t.title_bookmarks,
			command = 'script-binding uosc_history/bookmarks'
		}
	},
	{
		name = 'add_bookmarks',
		value = {
			icon = 'star',
			tooltip = t.bookmark_add,
			command = 'script-binding uosc_history/add_bookmarks'
		}
	},

}

local options, entries, all, dedup, folders, new, bookmark_entries, bookmark_items, new_bookmark
= {log = true, filter = 'dedup'}, {}, {}, {}, {}, {}, {}, {}, {}

local state ={
	-- 指示: 是否读取过日志
	-- 用于: 提示是否记录播放记录, openMenu是否需要readLog
	have_read = false, 
	-- 用于: resume(), 启动mpv和end-file后, mpv会有一次set pause的动作, 用于抵消这次pause改变触发的resume
	resumable = false, 
	-- 指示: 是否加载过文件
	-- 用于resume_in_folder, 避免下一集时resume
	loaded = false, 
	-- 指示: 加载行为是否来自脚本菜单
	-- 用于: resume_in_folder
	from_record = false, 
	-- 用于: 重命名书签
	pending_rename = nil, 
	-- 用于: 清空条目
	clear_type = nil, 
	-- 用于: 在播放记录菜单中添加收藏以后回到播放记录菜单
	menu_index_after_mark = nil,
	-- 用于: 判断选择书签文件夹以后是否成功加入, 使用前先设为nil
	delete_after_inserted = nil,
}

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

local function selectBookmarkFolder()
	local folders = {}
	folders[1] = {
		title = string.format('📁 %s',t.create_bookmark_folder),
		value = {
			new_folder = true,
			folder_index = true,
		},
		align = 'center',
		separator = true,
		-- italic = true,
	}

	for i,v in ipairs(bookmark_entries) do
		table.insert(folders, {
			title = v.title,
			value = {
				folder_index = i,
			},
		})
	end

	local menu_props = {
		id = 'select_folder',
		title = t.select_folder,
		items = folders,
		callback = {script_name, 'bookmark_menu_event'},
	}
	mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json(menu_props))
end

local function addBookmarks()
	if mp.get_property_bool('idle-active', 'false') then
		return
	end
		
	local title, path
	if next(new) then 
		title, path = new.media_title, new.path
	else
		path = mp.get_property('path', '')
		title = mp.get_property('media-title', '')
	end 
	new_bookmark = {title = title, value = path}

	selectBookmarkFolder()
end

local function clearBookmarks()
	state.clear_type = 'bookmarks'
	local menu_props = {
		title = t.clear_bookmarks,
		items = {
			{
				title = t.yes, icon = 'done', align = 'center', bold = 'true', 
				value = {'script-message-to', script_name, 'clear_confirmed'},
			}, 
			{
				title = t.no, icon = 'close', align = 'center', bold = 'true', 
				value = {'ignore'},
			},
		},
		selected_index = 2,
		search_style = 'disabled',
	}
	mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json(menu_props))
end

local function clearHistory()
	state.clear_type = 'history'
	local menu_props = {
		title = t.clear_history,
		items = {
			{
				title = t.yes, icon = 'done', align = 'center', bold = 'true', 
				value = {'script-message-to', script_name, 'clear_confirmed'},
			}, 
			{
				title = t.no, icon = 'close', align = 'center', bold = 'true', 
				value = {'ignore'},
			},
		},
		selected_index = 2,
		search_style = 'disabled',
	}
	mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json(menu_props))
end

local function clearConfirmed()
	if state.clear_type == 'history' then
		entries, all, dedup, folders  = {}, {}, {}, {}
	elseif state.clear_type == 'bookmarks' then
		bookmark_entries, bookmark_items = {}, {}
	end
end

local function readLog()
	local file = io.open(o.log_path, 'r')
	if file then
		local a = utils.parse_json(file:read("*a"))
		file:close()
		if a then
			options, entries, bookmark_entries = a.options or {log = true, filter = 'dedup'}, a.entries or {}, a.bookmark_entries or {}
			-- 兼容旧日志
			if a.bookmarks then
				local b_items = {}
				for _,v in ipairs(a.bookmarks) do 
					table.insert(b_items, {
						title = v.title,
						value = v.value.path
					})
				end
				table.insert(bookmark_entries, {
					title = t.old_bookmarks,
					items = b_items
				})
			end
		end
	end
	if not state.have_read then
		mp.msg.info(options.log == true and t.log_enabled or t.log_disabled)
	end
	state.have_read = true
end

local function writeLog()
	if not state.have_read then return end
	io.open(o.log_path, "w"):write(utils.format_json({
		options = options, 
		bookmark_entries = bookmark_entries, 
		entries = entries, 
	})):close()
end

local function getBookmarkItems()
	if next(bookmark_items) then return end
	if not next(bookmark_entries) then
		if state.have_read then return end 
		readLog()
	end

	for _,v in ipairs(bookmark_entries) do
		local folder = {title = v.title, items = {}}
		for _,w in ipairs(v.items) do
			local item = {title = w.title, value = w.value}
			table.insert(folder.items, item)
		end
		folder.item_actions = {
			{name = 'change', icon = 'reply_all', label = t.change_folder},
			{name = 'rename', icon = 'edit', label = t.rename_bookmark},
			{name = 'delete', icon = 'delete', label = t.del_bookmark},
		}
		folder.item_actions_place = 'outside'
		folder.on_move = 'callback'
		folder.callback = {script_name, 'bookmark_menu_event'}
		folder.footnote = t.move_bookmark_up .. '   ' .. t.move_bookmark_down .. '   ' .. t.rename_bookmarks
		
		table.insert(bookmark_items, folder)
	end
end

local function getItems()
	if next(all) then return end
	if not next(entries) then
		if state.have_read then return end 
		readLog()
	end
	all, dedup, folders = {}, {}, {}

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
			local title
			if o.filename then
				_,title = utils.split_path(entry.path) 
			else 
				title = entry.media_title
			end
			table.insert(all, {
				title = title,
				hint = entry.datetime,
				-- icon =  '',
				value = {
					path = entry.path,
					pos = entry.pos,
				},
			})
			if not seen_path[entry.path] then
				table.insert(dedup,{						
					title = title,
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

local function loadFile(value)
	local options = string.format('start=%d', value.pos or 0)
	if value.url then
		options = string.format('%s,force-media-title="%s"', options, value.media_title)
	end 
	if value.audio_path then 
		options = string.format('%s,audio-files="%s"', options, value.audio_path)
	end 
	mp.commandv('loadfile', value.path, 'replace',-1 , options)
end

local function getNewEntry() 
	new.media_title = mp.get_property('media-title', '')
	new.datetime = os.date('%Y/%m/%d  %H:%M')
	new.path = mp.get_property('path', '')
	new.progress = formatTime(mp.get_property_number('duration', 0))

	-- url
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

		local twice
		local function ob_duration(_, d)
			if d  and twice then
				new.progress = t.live
				mp.unobserve_property(ob_duration)
			end
			twice = true
			mp.add_timeout(3, function() mp.unobserve_property(ob_duration) end)
		end
		mp.observe_property('duration','number' ,ob_duration)
		return
	end

	-- upper_path and folder
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
	new.upper_path, new.folder = getFolder(new.path)
	
	-- resume_in_folder
	if o.resume_in_folder and not state.loaded and not state.from_record and next(entries) then
		if not next(all) then getItems() end

		for _,i in ipairs(folders) do
			local peer = i.value.peers[1]
			local entry = entries[peer]
			if new.upper_path == entry.upper_path and new.path ~= entry.path then
				mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json({
					title = t.resume_in_folder,
					selected_index = 1,
					items = {
						{
							title = entry.media_title,
							hint = entry.progress,
							active = true,
							icon = 'history',
							value = {path = entry.path,	pos = entry.pos}
						},
						{
							title =  new.media_title,
							hint = t.now,
							muted = true,
							selectable = false,
							icon = '',
						}
					},
					callback = {script_name, 'history_menu_event'},
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

	-- pos_in_folder
	local function findPosition(path)
		local dir_path, file_name = utils.split_path(path)
		local ext = file_name:match("^.+(%..+)$") or ""

		local function alphanumsort(filenames)
			local function padnum(n, d)
				return #d > 0 and ("%03d%s%.12f"):format(#n, n, tonumber(d) / (10 ^ #d))
					or ("%03d%s"):format(#n, n)
			end

			local tuples = {}
			for i, f in ipairs(filenames) do
				tuples[i] = {f:lower():gsub("0*(%d+)%.?(%d*)", padnum), f}
			end
			table.sort(tuples, function(a, b)
				return a[1] == b[1] and #b[2] < #a[2] or a[1] < b[1]
			end)
			for i, tuple in ipairs(tuples) do filenames[i] = tuple[2] end
			return filenames
		end

		local filenames = {}

		if platform == 'windows' then
			local ps_command = string.format([[
				[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new($false);
				Get-ChildItem -Name -LiteralPath "%s" -File -Filter "*%s"
			]], dir_path, ext)

			local result = utils.subprocess({
				args = {'powershell', '-NoProfile', '-Command', ps_command}, cancellable = false,
			})

			for filename in string.gmatch(result.stdout, '[^\r\n]+') do
				table.insert(filenames, filename)
			end
		else
			local result = utils.readdir(dir_path, "files")

			for _, filename in ipairs(result) do
				if filename:match("^.+(%..+)$") == ext then
					table.insert(filenames, filename)
				end
			end
		end

		alphanumsort(filenames)

		local current
		local count = #filenames

		for i = 1, count do
			if filenames[i] == file_name then
				current = i
				break
			end
		end
		
		return string.format('%s / %s', current, count)
	end	
	new.pos_in_folder = findPosition(new.path)
end

local function onUnload(hook) 
	if not next(new) then return end
	hook:defer()
	local pos = mp.get_property_number('time-pos', 0)
	hook:cont()
	if pos >= 3 then
		new.pos = pos - 3
	end
	if new.progress then
		new.progress = formatTime(pos) .. ' / ' .. new.progress
	end
end

local function enableHistory() 
	if not state.have_read then readLog() end
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
end

local function openBookmark(update, submenu_id)
	getBookmarkItems()

	local menu_props = {
		type = 'bookmarks',
		id = 'bookmarks',
		title = t.title_bookmarks,
		items = bookmark_items,
		on_move = 'callback',
		callback = {script_name, 'bookmark_menu_event'},
		footnote = t.move_bookmark_up .. '   ' .. t.move_bookmark_down .. '   ' .. t.delete_key .. '   ' .. t.rename_folders,
	}

	if update then
		mp.commandv('script-message-to', 'uosc', 'update-menu', utils.format_json(menu_props), submenu_id or '')
	else
		mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json(menu_props), submenu_id or '')
	end
end

local function openMenu(num, update) 
	getItems()

	local title, items
	if options.filter == 'all' then
		title = t.title_all .. ' (' .. tostring(#all) .. ')'
		items = all
	elseif options.filter == 'dedup' then
		title = t.title_dedup .. ' (' .. tostring(#dedup) .. ')'
		items = dedup
	elseif options.filter == 'folders' then
		title = t.title_folders .. ' (' .. tostring(#folders) .. ')'
		items = folders
	end
	
	local item_actions = {
		{name = 'mark', icon = 'star', label = t.bookmark_add},
		{name = 'delete', icon = 'delete', label = t.del},
	}

	local menu_props = {
		type = 'history',
		title = title,
		selected_index = num,
		items = items,
		item_actions = item_actions,
		footnote = t.footnote,
		callback = {script_name, 'history_menu_event'},
	}
	if update then
		mp.commandv('script-message-to', 'uosc', 'update-menu', utils.format_json(menu_props))
	else
		mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json(menu_props))
	end
end

local function toggleBookmark() 
	if mp.get_property_native('user-data/uosc/menu/type') ~= 'bookmarks' then
		openBookmark()
	else 
		mp.commandv('script-message-to', 'uosc', 'close-menu')
	end
end

local function toggleMenu() 
	if mp.get_property_native('user-data/uosc/menu/type') ~= 'history' then
		openMenu(1)	
	else 
		mp.commandv('script-message-to', 'uosc', 'close-menu')
	end
end

local function insertBookmarkEntries(folder_index, new_folder)
	if not new_bookmark then return end

	local function closeOrBack(index)
		if state.menu_index_after_mark then 
			openMenu(state.menu_index_after_mark) 
			state.menu_index_after_mark = nil
		else
			local submenu_id = folder_index and bookmark_entries[folder_index].title or new_folder
			openBookmark(_, submenu_id)
			mp.commandv(
				'script-message-to', 'uosc', 'select-menu-item', 'bookmarks', index, submenu_id
			)
		end
	end

	local function afterInsert(index)
		mp.osd_message(t.added)
		new_bookmark = nil
		bookmark_items = {}
		closeOrBack(index)
	end

	if folder_index then
		for _, bookmark in ipairs(bookmark_entries[folder_index].items) do
			if bookmark.value == new_bookmark.value then
				closeOrBack(#bookmark_entries[folder_index].items)
				mp.osd_message(t.bookmark_exists)
				return
			end
		end
		table.insert(bookmark_entries[folder_index].items, new_bookmark)
		afterInsert(#bookmark_entries[folder_index].items)
		return
	end

	-- 创建新收藏夹, 检查是否已存在
	for i,v in ipairs(bookmark_entries) do
		-- 如果存在直接插入
		if v.title == new_folder then
			for _, bookmark in ipairs(bookmark_entries[i].items) do
				if bookmark.value == new_bookmark.value then
					closeOrBack(#bookmark_entries[i].items)
					mp.osd_message(t.bookmark_exists)
					return
				end
			end
			table.insert(bookmark_entries[i].items, new_bookmark)
			afterInsert(#bookmark_entries[i].items)
			break
			return
		end
	end

	-- 不存在, 创建
	table.insert(bookmark_entries, {
		title = new_folder,
		items = {new_bookmark}
	})
	afterInsert(1)
end

local function moveBookmark(from_index, to_index, menu_id) 
	if menu_id == 'bookmarks' then
		local item = table.remove(bookmark_entries, from_index)
		table.insert(bookmark_entries, to_index, item)
		bookmark_items = {}
		openBookmark(true)
		mp.commandv(
			'script-message-to', 'uosc', 'select-menu-item', 'bookmarks', 
			tostring(to_index)
		)
	else
		for i,v in ipairs(bookmark_entries) do
			if v.title == menu_id then 
				local item = table.remove(bookmark_entries[i].items, from_index)
				table.insert(bookmark_entries[i].items, to_index, item)
				bookmark_items = {}
				openBookmark(true)
				mp.commandv(
					'script-message-to', 'uosc', 'select-menu-item', 'bookmarks', 
					tostring(to_index),
					menu_id
				)
				break
			end
		end
	end
end

local function renameType(menu_id, index)
	menu_props = {
		id = 'rename_bookmark',
		title = '',
		callback = {script_name, 'bookmark_menu_event'},
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
	state.pending_rename = {index = index}
	if menu_id == 'bookmarks' then
		state.pending_rename.folder = true
	else
		for i,v in ipairs(bookmark_entries) do
			if v.title == menu_id then 
				state.pending_rename.folder_index = i
				local title = bookmark_entries[i].items[index].title
				if string.len(title) < 150 then
					menu_props.search_suggestion = title
				end
				break
			end
		end
	end
	mp.commandv('script-message-to', 'uosc', 'open-menu',  utils.format_json(menu_props))
end

local function deleteHistoryEntries(peers, menu_index) 
	if options.filter == 'all' then
		table.remove(entries, menu_index)
	else
		for i = #peers, 1, -1 do
			table.remove(entries, peers[i])
		end
	end
	all = {}
	getItems()
	openMenu(menu_index,true)
end

local function deleteBookmarkEntries(menu_id, index)
	if menu_id == 'bookmarks' then 
		table.remove(bookmark_entries, index)
	else
		for i,v in ipairs(bookmark_entries) do
			if v.title == menu_id then 
				table.remove(bookmark_entries[i].items, index)
				break
			end
		end
	end
	bookmark_items = {}
	openBookmark(true)
end

local function resume() 
	if not state.have_read then readLog() end
	if next(entries) then
		mp.commandv('script-message-to', 'uosc', 'close-menu')
		loadFile({
			path = entries[1].path,
			pos = entries[1].pos,
			url = entries[1].url,
			media_title = entries[1].media_title,
			audio_path = entries[1].audio_path,
		})
		mp.set_property('pause', 'no')
	end
end

local function observePause(_, pause) 
	-- 抵消第一次触发; 
	if state.resumable then
		resume()
	end 
	state.resumable = true
end

local function fileLoaded() 
	if not state.have_read then readLog() end
	if options.log then	getNewEntry() end
	mp.unobserve_property(observePause)
	state.loaded = true
end

local function endFile() 
	if options.log and next(new) then
		table.insert(entries, 1, new)
		new, all  = {}, {}
	end
	state.resumable = false
	mp.observe_property('pause', 'bool', observePause)
end 

local function historyMenuEvent(json) 
	local event = utils.parse_json(json)
	if event.type == 'activate' then
		if event.action == 'delete' then
			-- 删除条目
			deleteHistoryEntries(event.value.peers, event.index)
		elseif event.action == 'mark' then
			local title
			if options.filter == 'all' then
				title = entries[event.index].media_title
			else
				title = entries[event.value.peers[1]].media_title
			end
			new_bookmark = {
				title = title,
				value = event.value.path,
			}
			state.menu_index_after_mark = event.index
			selectBookmarkFolder()
		elseif not event.action then
			if event.value then
				-- 加载文件
				loadFile(event.value)
				state.from_record = true
				-- 关闭菜单
				mp.commandv('script-message-to', 'uosc', 'close-menu')
			end
		end
	elseif event.type == 'key' then
		-- 切换过滤方式
		if (event.key == 'left' or event.key == 'right') and mp.get_property_native('user-data/uosc/menu/type') == 'history' then
			if options.filter == 'all' then options.filter = event.key == 'right' and 'dedup' or 'all'
			elseif options.filter == 'dedup' then options.filter = event.key == 'right' and 'folders' or 'all'
			elseif options.filter == 'folders' then options.filter = event.key == 'left' and 'dedup' or 'folders'
			end
			openMenu(1,true)
		elseif event.key == 'del' then
			-- 按键删除条目
			deleteHistoryEntries(event.selected_item.value.peers, event.selected_item.index)
		end
	end
end

local function bookmarkMenuEvent(json) 
	local event = utils.parse_json(json)
	if event.type == 'activate' then
		if event.action == 'delete' then
			-- 删除条目
			deleteBookmarkEntries(event.menu_id, event.index)
		elseif event.action == 'change' then
			for i,v in ipairs(bookmark_entries) do
				if v.title == event.menu_id then 
					new_bookmark = {title = bookmark_entries[i].items[event.index].title, value = event.value}
					break
				end
			end
			selectBookmarkFolder()
			mp.add_timeout(0.3, function()
				state.delete_after_inserted = {menu_id = event.menu_id, index = event.index}
			end)
		elseif event.action == 'rename' then
			renameType(event.menu_id, event.index)
		elseif not event.action then
			if not event.value then return end
			if not event.value.folder_index then
				-- 加载文件
				loadFile({path = event.value})
				state.from_record = true
				mp.commandv('script-message-to', 'uosc', 'close-menu')
				return
			end

			if state.delete_after_inserted and event.menu_id == 'select_folder' then
				deleteBookmarkEntries(state.delete_after_inserted.menu_id, state.delete_after_inserted.index)
				state.delete_after_inserted = nil
			end

			-- 添加到收藏夹
			if event.value.new_folder then
				-- 新建收藏夹, 等待键入名称
				local menu_props = {
					id = 'create_bookmark_folder',
					title = '',
					callback = {script_name, 'bookmark_menu_event'},
					on_search = 'callback',
					search_style = 'palette',
					search_debounce = 'submit',
					items = {{
						title = t.create_folder_tip,
						selectable = false, 
						italic = true,
						muted = true,
						align = 'right',
					}},
				}
				mp.commandv('script-message-to', 'uosc', 'open-menu', utils.format_json(menu_props))
			else-- 插入收藏夹
				insertBookmarkEntries(event.value.folder_index)
			end
		end
	elseif event.type == 'key' then
		if event.key == 'del' then
			-- 按键删除条目
			deleteBookmarkEntries(event.menu_id, event.selected_item.index)
		elseif (event.key == 'left' and event.menu_id == 'bookmarks')
		or (event.key == 'right' and event.menu_id ~= 'select_folder') then
			renameType(event.menu_id, event.selected_item.index)
		end
	elseif event.type == 'move' then
		-- 书签排序
		moveBookmark(event.from_index, event.to_index, event.menu_id)
	elseif event.type == 'search' then
		if event.menu_id == 'rename_bookmark' and state.pending_rename
		and event.query and event.query ~= '' then
			-- 书签重命名
			if state.pending_rename.folder then
				bookmark_entries[state.pending_rename.index].title = event.query
				bookmark_items = {}
				openBookmark()
				mp.commandv(
					'script-message-to', 'uosc', 'select-menu-item', 'bookmarks', 
					tostring(state.pending_rename.index)
				)
			else
				bookmark_entries[state.pending_rename.folder_index].items[state.pending_rename.index].title = event.query
				bookmark_items = {}
				openBookmark(_, bookmark_entries[state.pending_rename.folder_index].title)
				mp.commandv(
					'script-message-to', 'uosc', 'select-menu-item', 'bookmarks', 
					tostring(state.pending_rename.index), 
					bookmark_entries[state.pending_rename.folder_index].title
				)
			end
			state.pending_rename = nil
		elseif event.menu_id == 'create_bookmark_folder' and new_bookmark 
		and	event.query and event.query ~= '' then
			insertBookmarkEntries(nil, event.query)
		end
	elseif event.type == 'close' then
		state.delete_after_inserted = nil
	end
end

local function startup()
	for _, b in ipairs(buttons) do
		mp.commandv('script-message-to', 'uosc', 'set-button', b.name, utils.format_json(b.value))
	end 
	
	if mp.get_property_bool('idle-active', 'false') then
		mp.observe_property('pause', 'bool', observePause)
		if o.start_action == 'menu' then 			
			toggleMenu()
		elseif o.start_action == 'resume' then
			resume()
		end
	end
end



startup()
mp.add_hook('on_unload', 50, onUnload)
mp.register_event('file-loaded', fileLoaded)
mp.register_event('end-file', endFile)
mp.register_event('shutdown', writeLog)
mp.add_key_binding(nil, 'history', toggleMenu)
mp.add_key_binding(nil, 'enable_history', enableHistory)
mp.add_key_binding(nil, 'clear_history', clearHistory)
mp.add_key_binding(nil, 'bookmarks', toggleBookmark)
mp.add_key_binding(nil, 'add_bookmarks', addBookmarks)
mp.add_key_binding(nil, 'clear_bookmarks', clearBookmarks)
mp.register_script_message('clear_confirmed', clearConfirmed)
mp.register_script_message('history_menu_event', historyMenuEvent)
mp.register_script_message('bookmark_menu_event', bookmarkMenuEvent)