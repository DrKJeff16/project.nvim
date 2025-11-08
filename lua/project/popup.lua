---@class Project.Popup.SelectChoices
---@field choices fun(): table<string, function>
---@field choices_list fun(): string[]

---@class Project.Popup.SelectSpec: Project.Popup.SelectChoices
---@field callback ProjectCmdFun

local MODSTR = 'project.popup'
local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local in_list = vim.list_contains
local empty = vim.tbl_isempty

local Util = require('project.utils.util')

---CREDITS: [u/Some_Derpy_Pineapple](https://www.reddit.com/r/neovim/comments/1nu5ehj/comment/ngyz21m/)
local FILE_ATTRIBUTE_HIDDEN = 0x2
local ffi = nil ---@type nil|ffilib
if Util.mod_exists('ffi') then
    ffi = require('ffi')
    ffi.cdef([[
    int GetFileAttributesA(const char *path);
    ]])
end

---@param path string
---@param hidden boolean
---@return boolean
local function hidden_avail(path, hidden)
    if Util.vim_has('nvim-0.11') then
        vim.validate('path', path, 'string', false)
        vim.validate('hidden', hidden, 'boolean', false)
    else
        vim.validate({
            path = { path, 'string' },
            hidden = { hidden, 'boolean' },
        })
    end

    local fd = Util.executable('fd') and 'fd' or (Util.executable('fdfind') and 'fdfind' or '')
    if fd == '' then
        error(('(%s.hidden_avail): `fd`/`fdfind` could be found PATH!'):format(MODSTR), ERROR)
    end

    local cmd = { fd, '-Iad1' }
    if hidden then
        table.insert(cmd, '-H')
    end

    local out = vim.system(cmd, { text = true, cwd = vim.g.project_nvim_cwd }):wait(1000).stdout
    if not out then
        return false
    end

    local ret = false
    local nodes = vim.split(out, '\n', { plain = true, trimempty = true })
    vim.tbl_map(function(value)
        if value == path or vim.startswith(value, path) then
            ret = true
        end
    end, nodes)
    return ret
end

---Attempt to find out if given path is a hidden file.
---**Works only Windows, currently!**
---
---CREDITS:
---https://github.com/nvim-neo-tree/neo-tree.nvim/blob/8dd9f08ff086d09d112f1873f88dc0f74b598cdb/lua/neo-tree/utils/init.lua#L1299
--- ---
---@param path string
---@return boolean
local function is_hidden(path)
    if Util.vim_has('nvim-0.11') then
        vim.validate('path', path, 'string', false)
    else
        vim.validate({ path = { path, 'string' } })
    end
    if Util.is_windows() then
        if ffi then
            return bit.band(ffi.C.GetFileAttributesA(path), FILE_ATTRIBUTE_HIDDEN) ~= 0
        end

        return false -- FIXME: Find a reliable alternative
    end

    return false --- TODO: Find a reliable method for UNIX systems
end

---@param proj string
---@param only_cd boolean
---@param ran_cd boolean
local function open_node(proj, only_cd, ran_cd)
    if Util.vim_has('nvim-0.11') then
        vim.validate('proj', proj, 'string', false)
        vim.validate('only_cd', only_cd, 'boolean', false)
        vim.validate('ran_cd', ran_cd, 'boolean', false)
    else
        vim.validate({
            proj = { proj, 'string' },
            only_cd = { only_cd, 'boolean' },
            ran_cd = { ran_cd, 'boolean' },
        })
    end
    if not ran_cd then
        local success = require('project.api').set_pwd(proj, 'prompt')
        if not success then
            vim.notfy('(open_node): Unsucessful `set_pwd`!', ERROR)
            return
        end
        if only_cd then
            return
        end
        ran_cd = not ran_cd
        vim.g.project_nvim_cwd = proj
    end

    local dir = vim.uv.fs_scandir(proj)
    if not dir then
        vim.notify(('(%s.open_node): NO DIR `%s`!'):format(MODSTR, proj), ERROR)
        return
    end

    local hidden = require('project.config').options.show_hidden
    local ls = {}
    while true do
        local node = vim.uv.fs_scandir_next(dir)
        if not node then
            break
        end
        node = proj .. '/' .. node
        local stat = vim.uv.fs_stat(node)
        if stat then
            local hid = is_hidden(node)
            if (hidden and hid) or hidden_avail(node, hidden) then
                table.insert(ls, node)
            end
        end
    end
    table.insert(ls, 'Exit')

    vim.ui.select(ls, {
        prompt = 'Select a file:',
        format_item = function(item) ---@param item string
            if item == 'Exit' then
                return item
            end

            item = Util.rstrip('/', vim.fn.fnamemodify(item, ':p'))
            return vim.fn.isdirectory(item) == 1 and (item .. '/') or item
        end,
    }, function(item) ---@param item string
        if not item or in_list({ '', 'Exit' }, item) then
            return
        end

        item = Util.rstrip('/', vim.fn.fnamemodify(item, ':p'))
        local stat = vim.uv.fs_stat(item)
        if not stat then
            return
        end
        if stat.type == 'file' then
            vim.g.project_nvim_cwd = ''
            vim.cmd.edit(item)
            return
        end
        if stat.type == 'directory' then
            vim.g.project_nvim_cwd = item
            open_node(item, false, ran_cd)
        end
    end)
end

---@class Project.Popup
local Popup = {}

---@class Project.Popup.Select
Popup.select = {}

---@param opts Project.Popup.SelectSpec
---@return Project.Popup.SelectChoices|ProjectCmdFun
function Popup.select.new(opts)
    if Util.vim_has('nvim-0.11') then
        vim.validate('opts', opts, 'table', false, 'Project.Popup.SelectSpec')
    else
        vim.validate({
            opts = { opts, 'table' },
            choices = { opts.choices, 'function' },
            choices_list = { opts.choices_list, 'function' },
            callback = { opts.callback, 'function' },
        })
    end
    if empty(opts) then
        error(('(%s.select.new): Empty args for constructor!'):format(MODSTR), ERROR)
    end
    if Util.vim_has('nvim-0.11') then
        vim.validate('choices', opts.choices, 'function', false, 'fun(): table<string, function>')
        vim.validate('choices_list', opts.choices_list, 'function', false, 'fun(): string[]')
        vim.validate('callback', opts.callback, 'function', false)
    else
        vim.validate({
            choices = { opts.choices, 'function' },
            choices_list = { opts.choices_list, 'function' },
            callback = { opts.callback, 'function' },
        })
    end

    ---@type Project.Popup.SelectChoices|ProjectCmdFun
    local T = setmetatable({
        choices = opts.choices,
        choices_list = opts.choices_list,
    }, {
        ---@param t Project.Popup.SelectChoices|ProjectCmdFun
        ---@param k string
        __index = function(t, k)
            return rawget(t, k)
        end,
        ---@param ctx? vim.api.keyset.create_user_command.command_args
        __call = function(_, ctx)
            if not ctx then
                opts.callback()
                return
            end
            opts.callback(ctx)
        end,
    })
    return T
end

---@param input string|nil
function Popup.prompt_project(input)
    if Util.vim_has('nvim-0.11') then
        vim.validate('input', input, 'string', true, 'string|nil')
    else
        vim.validate({ input = { input, { 'string', 'nil' } } })
    end
    if not input or input == '' then
        return
    end

    local Path = require('project.utils.path')
    local original_input = input
    input = Util.rstrip('/', vim.fn.fnamemodify(input, ':p'))
    if not (Path.exists(input) and Path.exists(vim.fn.fnamemodify(input, ':p:h'))) then
        vim.notify(('Invalid path `%s`'):format(original_input), ERROR)
        return
    end
    if not Util.dir_exists(input) then
        input = Util.rstrip('/', vim.fn.fnamemodify(input, ':p:h'))
        if not Util.dir_exists(input) then
            vim.notify('Path is not a directory, and parent could not be retrieved!', ERROR)
            return
        end
    end

    local Api = require('project.api')
    local session = require('project.utils.history').session_projects
    if Api.current_project == input or in_list(session, input) then
        vim.notify('Already added that directory!', WARN)
        return
    end
    Api.set_pwd(input, 'prompt')
    require('project.utils.history').write_history()
end

Popup.delete_menu = Popup.select.new({
    callback = function()
        local choices_list = Popup.delete_menu.choices_list()
        vim.ui.select(choices_list, {
            prompt = 'Select a project to delete:',
            format_item = function(item) ---@param item string
                local session = require('project.utils.history').session_projects
                if in_list(session, item) then
                    return '* ' .. item
                end
                return item
            end,
        }, function(item)
            if not item then
                return
            end
            if not in_list(choices_list, item) then
                vim.notify('Bad selection!', ERROR)
                return
            end

            local choice = Popup.delete_menu.choices()[item]
            if not (choice and vim.is_callable(choice)) then
                vim.notify('Bad selection!', ERROR)
                return
            end

            choice()
        end)
    end,
    choices_list = function()
        ---@type string[]
        local recents = Util.reverse(require('project.utils.history').get_recent_projects())
        table.insert(recents, 'Exit')
        return recents
    end,
    choices = function()
        ---@type table<string, fun()>
        local T = {}
        for _, proj in ipairs(require('project.utils.history').get_recent_projects()) do
            T[proj] = function()
                require('project.utils.history').delete_project(proj)
            end
        end
        T.Exit = function() end
        return T
    end,
})

Popup.recents_menu = Popup.select.new({
    callback = function()
        local choices_list = Popup.recents_menu.choices_list()
        vim.ui.select(choices_list, {
            prompt = 'Select a project:',
            format_item = function(item) ---@param item string
                local curr = require('project.api').current_project or ''
                return item == curr and '* ' .. item or item
            end,
        }, function(item)
            if not item then
                return
            end
            if not in_list(choices_list, item) then
                vim.notify('Bad selection!', ERROR)
                return
            end
            local choice = Popup.recents_menu.choices()[item]
            if not (choice and vim.is_callable(choice)) then
                vim.notify('Bad selection!', ERROR)
                return
            end

            choice(item, false, false)
        end)
    end,
    choices_list = function()
        local choices_list = vim.deepcopy(require('project.utils.history').get_recent_projects())
        if require('project.config').options.telescope.sort == 'newest' then
            choices_list = Util.reverse(choices_list)
        end

        table.insert(choices_list, 'Exit')
        return choices_list
    end,
    choices = function()
        local choices = {} ---@type table<string, function>
        for _, s in ipairs(Popup.recents_menu.choices_list()) do
            choices[s] = s ~= 'Exit' and open_node or function(_, _, _) end
        end
        return choices
    end,
})

Popup.open_menu = Popup.select.new({
    callback = function()
        local choices_list = Popup.open_menu.choices_list()
        vim.ui.select(choices_list, {
            prompt = 'Select an operation:',
        }, function(item)
            if not item then
                return
            end
            if not in_list(choices_list, item) then
                vim.notify('Bad selection!', ERROR)
                return
            end
            local choice = Popup.open_menu.choices()[item]
            if not (choice and vim.is_callable(choice)) then
                vim.notify('Bad selection!', ERROR)
                return
            end

            choice()
        end)
    end,
    choices = function()
        local Config = require('project.config')
        local res = { ---@type table<string, ProjectCmdFun>
            ['Project Session'] = function()
                Popup.session_menu()
            end,
            ['New Project'] = function()
                require('project.commands').ProjectAdd()
            end,
            ['Open Recent Project'] = function()
                Popup.recents_menu()
            end,
            ['Delete A Project'] = function()
                Popup.delete_menu()
            end,
            ['Show Config'] = function()
                require('project.commands').ProjectConfig()
            end,
            ['Open History'] = function()
                vim.cmd.ProjectHistory()
            end,
            ['Open Help Docs'] = function()
                vim.cmd.help('project-nvim')
            end,
            ['Run Checkhealth'] = function()
                vim.cmd.checkhealth('project')
            end,
            ['Go To Source Code'] = function()
                vim.ui.open('https://github.com/DrKJeff16/project.nvim')
            end,
            Exit = function() end,
        }
        if vim.g.project_telescope_loaded == 1 then
            res['Open Telescope Picker'] = function()
                require('telescope._extensions.projects').projects()
            end
        end
        if Config.options.fzf_lua.enabled then
            res['Open Fzf-Lua Picker'] = function()
                require('project.extensions.fzf-lua').run_fzf_lua()
            end
        end
        if Config.options.log.enabled then
            res['Open Log'] = function()
                require('project.utils.log').open_win()
            end
            res['Clear Log'] = function()
                require('project.utils.log').clear_log()
            end
        end
        return res
    end,
    choices_list = function()
        local Config = require('project.config')
        local res_list = {
            'Project Session',
            'New Project',
            'Open Recent Project',
            'Delete A Project',
            'Run Checkhealth',
            'Show Config',
            'Open History',
            'Open Help Docs',
            'Go To Source Code',
            'Exit',
        }
        if vim.g.project_telescope_loaded == 1 then
            table.insert(res_list, #res_list - 5, 'Open Telescope Picker')
        end
        if Config.options.fzf_lua.enabled then
            table.insert(res_list, #res_list - 5, 'Open Fzf-Lua Picker')
        end
        if Config.options.log.enabled then
            table.insert(res_list, #res_list - 5, 'Open Log')
            table.insert(res_list, #res_list - 5, 'Clear Log')
        end
        return res_list
    end,
})

Popup.session_menu = Popup.select.new({
    callback = function(ctx)
        local only_cd = false
        if ctx then
            only_cd = ctx.bang ~= nil and ctx.bang or only_cd
        end

        local choices_list = Popup.session_menu.choices_list()
        if #choices_list == 1 then
            vim.notify('No sessions available!', WARN)
            return
        end

        vim.ui.select(choices_list, {
            prompt = 'Select a project from your session:',
            format_item = function(item) ---@param item string
                return vim.fn.isdirectory(item) == 1 and (item .. '/') or item
            end,
        }, function(item)
            if not item then
                return
            end
            if not in_list(choices_list, item) then
                vim.notify('Bad selection!', ERROR)
                return
            end
            local choice = Popup.session_menu.choices()[item]
            if not (choice and vim.is_callable(choice)) then
                vim.notify('Bad selection!', ERROR)
                return
            end

            choice(item, only_cd, false)
        end)
    end,
    choices = function()
        local sessions = require('project.utils.history').session_projects
        local choices = { Exit = function(_, _, _) end }
        if vim.tbl_isempty(sessions) then
            return choices
        end
        for _, proj in ipairs(sessions) do
            choices[proj] = open_node
        end
        return choices
    end,
    choices_list = function()
        local choices = vim.deepcopy(require('project.utils.history').session_projects)
        table.insert(choices, 'Exit')
        return choices
    end,
})

return Popup
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
