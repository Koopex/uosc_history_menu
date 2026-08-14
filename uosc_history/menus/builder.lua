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

--- 构建重命名/输入面板菜单：title 显示在菜单顶部说明用途（避免被误认为搜索框），
--- hint 为底部操作提示
function M.input_dialog(title, hint, callback, id, initial_value)
    local props = {
        id = id,
        title = title,
        callback = callback,
        on_search = 'callback',
        search_style = 'palette',
        search_debounce = 'submit',
        items = {{
            title = hint,
            selectable = false,
            italic = true,
            align = 'center',
        }},
    }
    if initial_value and #initial_value > 0 and #initial_value < 150 then
        props.search_suggestion = initial_value
    end
    return props
end

return M
