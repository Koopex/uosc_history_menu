-- 收藏菜单：打开/更新/分组选择 + 事件路由

local M = {}

local mp
local utils
local script_name
local I18N
local bookmarks
local builder
local history_menu

M.global_actions = nil

local pending = {
    rename_type = nil,
    rename_type_was_folder = nil,
    rename_folder_index = nil,
    rename_item_index = nil,
    delete_after_inserted = nil,
    pending_bookmark = nil,
    mark_return_pending = false,
}

function M.init(params)
    mp = params.mp; utils = params.utils; script_name = params.script_name
    I18N = params.i18n; bookmarks = params.bookmarks; builder = params.builder
    history_menu = params.history_menu
end

function M.set_pending_bookmark(bm)
    pending.pending_bookmark = bm
end

function M.set_mark_return_pending()
    pending.mark_return_pending = true
end

function M.open(update, submenu_id)
    pending.in_change_folder = false
    local items = bookmarks.get_menu_items(
        { script_name, 'bookmark_menu_event' },
        { move_bookmark_up=I18N.move_bookmark_up, move_bookmark_down=I18N.move_bookmark_down,
          delete_key=I18N.delete_key, rename_bookmarks=I18N.rename_bookmarks, rename_folders=I18N.rename_folders,
          change_folder=I18N.change_folder, rename_bookmark=I18N.rename_bookmark, del_bookmark=I18N.del_bookmark })
    local props = { type='bookmarks', id='bookmarks', title=I18N.title_bookmarks, items=items,
        on_move='callback', callback={script_name,'bookmark_menu_event'},
        footnote=I18N.move_bookmark_up..'   '..I18N.move_bookmark_down..'   '..I18N.delete_key..'   '..I18N.rename_folders }
    if update then
        if submenu_id then
            mp.commandv('script-message-to','uosc','update-menu',utils.format_json(props),submenu_id)
        else
            mp.commandv('script-message-to','uosc','update-menu',utils.format_json(props))
        end
    else
        if submenu_id then
            mp.commandv('script-message-to','uosc','open-menu',utils.format_json(props),submenu_id)
        else
            mp.commandv('script-message-to','uosc','open-menu',utils.format_json(props))
        end
    end
end

function M.toggle()
    if mp.get_property_native('user-data/uosc/menu/type') ~= 'bookmarks' then
        pending.in_change_folder = false
        M.open(false)
    else mp.commandv('script-message-to','uosc','close-menu') end
end

function M.open_folder_selector()
    local folders = {}
    folders[1] = { title=I18N.create_bookmark_folder, value={new_folder=true, folder_index=true}, align='center', separator=true }
    for i,v in ipairs(bookmarks.get_entries()) do table.insert(folders,{title=v.title,value={folder_index=i}}) end
    mp.commandv('script-message-to','uosc','open-menu',utils.format_json({
        id='select_folder', title=I18N.select_folder, items=folders,
        callback={script_name,'bookmark_menu_event'} }))
end

function M.start_add_bookmark(title, value, quick_mark)
    pending.pending_bookmark = {title=title, value=value}
    if quick_mark then M._do_insert(nil, I18N.quick_mark_folder) else M.open_folder_selector() end
end

function M._do_insert(folder_index, new_folder_name)
    if not pending.pending_bookmark then return end
    local bm = pending.pending_bookmark
    local inserted_index, is_duplicate
    if folder_index then inserted_index = bookmarks.add_to_folder(folder_index, bm)
    elseif new_folder_name then
        local _, item_idx, created = bookmarks.add_to_new_folder(new_folder_name, bm, true)
        inserted_index = item_idx; is_duplicate = (not created and item_idx)
    end
    mp.osd_message((not inserted_index or is_duplicate) and I18N.bookmark_exists or I18N.added)
    pending.pending_bookmark = nil
    if not pending.mark_return_pending then
        local sid
        if new_folder_name and new_folder_name ~= I18N.quick_mark_folder then
            sid = new_folder_name
            M.open(false, sid)
        elseif folder_index then
            local entries = bookmarks.get_entries()
            sid = entries[folder_index] and entries[folder_index].title
            if sid then M.open(false, sid) end
        end
        if inserted_index and sid then
            mp.commandv('script-message-to','uosc','select-menu-item','bookmarks',tostring(inserted_index),sid)
        end
    end
    if pending.mark_return_pending then pending.mark_return_pending = false; if history_menu then history_menu.return_after_mark() end end
end

function M._delete_after_insert()
    local d = pending.delete_after_inserted; if not d then return end
    for i,v in ipairs(bookmarks.get_entries()) do if v.title == d.menu_id then bookmarks.remove_item(i, d.index); break end end
    pending.delete_after_inserted = nil; pending.in_change_folder = false
end

-- Event handlers
M.handlers = {}

function M.handlers.activate(event)
    local a = event.action
    if a == 'delete' then
        if event.menu_id == 'bookmarks' then bookmarks.remove_folder(event.index)
        else for i,v in ipairs(bookmarks.get_entries()) do if v.title==event.menu_id then bookmarks.remove_item(i,event.index); break end end end
        bookmarks.invalidate_cache(); M.open(true)
    elseif a == 'change' then
        for i,v in ipairs(bookmarks.get_entries()) do if v.title==event.menu_id then
            pending.pending_bookmark = {title=bookmarks.get_entries()[i].items[event.index].title, value=event.value}; break end end
        pending.delete_after_inserted = {menu_id=event.menu_id, index=event.index}
        pending.in_change_folder = true
        M.open_folder_selector()
    elseif a == 'rename' then
        M._show_rename_dialog(event.menu_id, event.index)
    elseif not a then
        if not event.value then return end
        if event.value.folder_index then
            if pending.delete_after_inserted and event.menu_id=='select_folder' then M._delete_after_insert() end
            if event.value.new_folder then
                mp.commandv('script-message-to','uosc','open-menu', utils.format_json(
                    builder.input_dialog(I18N.create_folder_tip, {script_name,'bookmark_menu_event'}, 'create_bookmark_folder')))
            else M._do_insert(event.value.folder_index) end
        else
            if M.global_actions then M.global_actions.load_file({path=event.value}) end
            mp.commandv('script-message-to','uosc','close-menu')
        end
    end
end

function M.handlers.key(event)
    if event.key == 'del' then
        local idx = event.selected_item and event.selected_item.index; if not idx then return end
        if event.menu_id == 'bookmarks' then bookmarks.remove_folder(idx)
        else for i,v in ipairs(bookmarks.get_entries()) do if v.title==event.menu_id then bookmarks.remove_item(i,idx); break end end end
        bookmarks.invalidate_cache(); M.open(true)
    elseif event.key == 'left' and event.menu_id == 'bookmarks' then
        if event.selected_item then
            M._show_rename_dialog(event.menu_id, event.selected_item.index)
        end
    elseif event.key == 'right' and event.menu_id ~= 'select_folder' then
        -- Only show rename if folder has items
        local has_items = false
        if event.menu_id == 'bookmarks' then
            has_items = event.selected_item ~= nil
        else
            for _, v in ipairs(bookmarks.get_entries()) do
                if v.title == event.menu_id then
                    has_items = (v.items and #v.items > 0)
                    break
                end
            end
        end
        if has_items and event.selected_item then
            M._show_rename_dialog(event.menu_id, event.selected_item.index)
        end
    end
end

function M.handlers.move(event)
    if event.menu_id == 'bookmarks' then bookmarks.move_folder(event.from_index, event.to_index)
    else for i,v in ipairs(bookmarks.get_entries()) do if v.title==event.menu_id then bookmarks.move_item(i,event.from_index,event.to_index); break end end end
    bookmarks.invalidate_cache()
    local submenu = event.menu_id ~= 'bookmarks' and event.menu_id or nil
    M.open(true, submenu)
    if submenu then
    mp.commandv('script-message-to','uosc','select-menu-item','bookmarks',tostring(event.to_index),submenu)
else
    mp.commandv('script-message-to','uosc','select-menu-item','bookmarks',tostring(event.to_index))
end
end

function M.handlers.search(event)
    if event.menu_id == 'rename_bookmark' and event.query and event.query ~= '' then
        if pending.rename_type == 'folder' then bookmarks.rename_folder(pending.rename_folder_index, event.query)
        else bookmarks.rename_item(pending.rename_folder_index, pending.rename_item_index, event.query) end
        bookmarks.invalidate_cache()
        if pending.rename_type_was_folder then
            M.open(false)
            mp.commandv('script-message-to','uosc','select-menu-item','bookmarks',tostring(pending.rename_folder_index))
        else
            local ft = bookmarks.get_entries()[pending.rename_folder_index] and bookmarks.get_entries()[pending.rename_folder_index].title
            M.open(false, ft)
            mp.commandv('script-message-to','uosc','select-menu-item','bookmarks',tostring(pending.rename_item_index),ft)
        end
        pending.rename_type = nil
    elseif event.menu_id == 'create_bookmark_folder' and pending.pending_bookmark and event.query and event.query ~= '' then
        M._do_insert(nil, event.query)
    end
end

function M.handlers.close(event) if not pending.in_change_folder then pending.delete_after_inserted = nil end end

function M._show_rename_dialog(menu_id, index)
    pending.rename_type = (menu_id=='bookmarks') and 'folder' or 'item'
    pending.rename_type_was_folder = (menu_id=='bookmarks')
    pending.rename_folder_index = index; pending.rename_item_index = index
    if menu_id ~= 'bookmarks' then
        for i,v in ipairs(bookmarks.get_entries()) do if v.title==menu_id then
            pending.rename_folder_index = i; pending.rename_item_index = index
            local title = ''; local e = bookmarks.get_entries()
            if e[i] and e[i].items and e[i].items[index] then title = e[i].items[index].title end
            mp.commandv('script-message-to','uosc','open-menu', utils.format_json(
                builder.input_dialog(I18N.rename_bookmark_hint, {script_name,'bookmark_menu_event'}, 'rename_bookmark', title)))
            return
        end end
    end
    local title = ''; local e = bookmarks.get_entries()
    if e[index] then title = e[index].title end
    mp.commandv('script-message-to','uosc','open-menu', utils.format_json(
        builder.input_dialog(I18N.rename_bookmark_hint, {script_name,'bookmark_menu_event'}, 'rename_bookmark', title)))
end

function M.handle_event(json)
    local event = utils.parse_json(json)
    if not event or not event.type then return end
    local handler = M.handlers[event.type]
    if type(handler) == 'function' then handler(event) end
end

return M
