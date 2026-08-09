-- 通用菜单属性构造器

local M = {}

local script_name

function M.init(params)
    script_name = params.script_name
end

--- 构建确认对话框菜单
function M.confirm_dialog(title, yes_text, no_text, on_confirm)
    return {
        type = 'menu',
        title = title,
        selected_index = 2,
        items = {
            {
                title = yes_text, icon = 'done', align = 'center', bold = true,
                value = 'yes', selectable = true,
            },
            {
                title = no_text, icon = 'close', align = 'center', bold = true,
                value = 'no', selectable = true,
            },
        },
        callback = on_confirm,
    }
end

--- 构建重命名/输入面板菜单
function M.input_dialog(hint, callback, id, initial_value)
    local props = {
        id = id,
        title = '',
        callback = callback,
        on_search = 'callback',
        search_style = 'palette',
        search_debounce = 'submit',
        items = {{
            title = hint,
            selectable = false,
            italic = true,
            muted = true,
            align = 'right',
        }},
    }
    if initial_value and #initial_value < 150 then
        props.search_suggestion = initial_value
    end
    return props
end

--- 构建分组选择列表菜单
function M.folder_list_menu(folders, title, callback, create_label)
    local items = {}
    items[1] = {
        title = create_label,
        value = { new_folder = true, folder_index = true },
        align = 'center',
        separator = true,
    }
    for i, v in ipairs(folders) do
        table.insert(items, {
            title = v.title,
            value = { folder_index = i },
        })
    end
    return {
        id = 'select_folder',
        title = title,
        items = items,
        callback = callback,
    }
end

return M
