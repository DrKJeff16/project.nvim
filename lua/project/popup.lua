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
local History = require('project.utils.history')
local Path = require('project.utils.path')
local Config = require('project.config')
local exists = Path.exists
local get_recent_projects = History.get_recent_projects
local vim_has = Util.vim_has

---CREDITS: [u/Some_Derpy_Pineapple](https://www.reddit.com/r/neovim/comments/1nu5ehj/comment/ngyz21m/)
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
    if vim.fn.executable('fd') ~= 1 then
        error('`fd` not found in your PATH!', ERROR)
    end

    local cmd = { 'fd', '-Iad1' }
    if hidden then
        table.insert(cmd, '-H')
    end

    local out = vim.system(cmd, {
        text = true,
        cwd = vim.g.project_nvim_cwd,
    })
        :wait().stdout
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

---For Windows.
---
---CREDITS: [`neo-tree.nvim`](https://github.com/nvim-neo-tree/neo-tree.nvim/blob/8dd9f08ff086d09d112f1873f88dc0f74b598cdb/lua/neo-tree/utils/init.lua#L1299)
--- ---
---@param path string
---@return boolean
local function is_hidden(path)
    if Util.vim_has('nvim-0.11') then
        vim.validate('path', path, 'string', false)
    else
        vim.validate({ path = { path, 'string' } })
    end
    local FILE_ATTRIBUTE_HIDDEN = 0x2
    if ffi and Util.is_windows() then
        return bit.band(ffi.C.GetFileAttributesA(path), FILE_ATTRIBUTE_HIDDEN) ~= 0
    end

    return false
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
            error('(open_node): Unsucessful `set_pwd`!')
        end
        if only_cd then
            return
        end
        ran_cd = not ran_cd
        vim.g.project_nvim_cwd = proj
    end

    local hidden = require('project.config').options.show_hidden
    local dir = vim.uv.fs_scandir(proj)
    if not dir then
        error(('NO DIR `%s`!'):format(proj))
    end
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

    vim.ui.select(ls, {
        prompt = 'Select a file:',
        format_item = function(item) ---@param item string
            return vim.fn.isdirectory(item) == 1 and (item .. '/') or item
        end,
    }, function(item) ---@param item string
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
---@return Project.Popup.Select|Project.Popup.SelectChoices|ProjectCmdFun
function Popup.select.new(opts)
    if vim_has('nvim-0.11') then
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
    if vim_has('nvim-0.11') then
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

    ---@type Project.Popup.Select|Project.Popup.SelectChoices|ProjectCmdFun
    local T = setmetatable({
        choices = opts.choices,
        choices_list = opts.choices_list,
    }, {
        ---@param t Project.Popup.Select|Project.Popup.SelectChoices|ProjectCmdFun
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
    if vim_has('nvim-0.11') then
        vim.validate('input', input, 'string', true, 'string|nil')
    else
        vim.validate({ input = { input, { 'string', 'nil' } } })
    end
    if not input or input == '' then
        return
    end
    if not (exists(input) and exists(vim.fn.fnamemodify(input, ':p:h'))) then
        error('Invalid path!', ERROR)
    end
    if not Util.dir_exists(input) then
        input = vim.fn.fnamemodify(input, ':p:h')
        if not Util.dir_exists(input) then
            error('Path is not a directory, and parent could not be retrieved!', ERROR)
        end
    end

    local Api = require('project.api')
    local recent = History.get_recent_projects()
    if Api.current_project == input or in_list(recent, input) then
        vim.notify('Already added that directory!', WARN)
        return
    end
    Api.set_pwd(input, 'prompt')
    History.write_history()
end

Popup.delete_menu = Popup.select.new({
    callback = function()
        vim.ui.select(Popup.delete_menu.choices_list(), {
            prompt = 'Select a project to delete:',
            format_item = function(item)
                local session = History.session_projects
                if in_list(session, item) then
                    return '* ' .. item
                end
                return item
            end,
        }, function(item)
            if not (item and in_list(Popup.delete_menu.choices_list(), item)) then
                error('Bad selection!', ERROR)
            end

            local choices = Popup.delete_menu.choices()
            local op = choices[item]
            if not (op and vim.is_callable(op)) then
                error('Bad selection!', ERROR)
            end

            op()
        end)
    end,
    choices_list = function()
        ---@type string[]
        local recents = Util.reverse(get_recent_projects())
        table.insert(recents, 'Exit')
        return recents
    end,
    choices = function()
        ---@type table<string, fun()>
        local T = {}
        for _, proj in ipairs(get_recent_projects()) do
            T[proj] = function()
                History.delete_project(proj)
            end
        end
        T['Exit'] = function() end
        return T
    end,
})

Popup.open_menu = Popup.select.new({
    callback = function()
        vim.ui.select(Popup.open_menu.choices_list(), {
            prompt = 'Select an operation:',
        }, function(item)
            if not item then
                return
            end
            if not in_list(Popup.open_menu.choices_list(), item) then
                error('Bad selection!', ERROR)
            end
            local choices = Popup.open_menu.choices()
            local op = choices[item]
            if not (op and vim.is_callable(op)) then
                error('Bad selection!', ERROR)
            end

            op()
        end)
    end,
    choices = function()
        ---@type table<string, ProjectCmdFun>
        local res = {
            ['Project Session'] = function()
                Popup.session_menu()
            end,
            ['New Project'] = function()
                require('project.commands').ProjectAdd()
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
            ['Exit'] = function() end,
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
        ---@type string[]
        local res_list = {
            'Project Session',
            'New Project',
            'Delete A Project',
        }
        if vim.g.project_telescope_loaded == 1 then
            table.insert(res_list, 'Open Telescope Picker')
        end
        if Config.options.fzf_lua.enabled then
            table.insert(res_list, 'Open Fzf-Lua Picker')
        end
        if Config.options.log.enabled then
            table.insert(res_list, 'Open Log')
            table.insert(res_list, 'Clear Log')
        end
        table.insert(res_list, 'Show Config')
        table.insert(res_list, 'Open History')
        table.insert(res_list, 'Run Checkhealth')
        table.insert(res_list, 'Open Help Docs')
        table.insert(res_list, 'Exit')
        return res_list
    end,
})

Popup.session_menu = Popup.select.new({
    callback = function(ctx)
        local only_cd = false
        if ctx then
            only_cd = ctx.bang ~= nil and ctx.bang or only_cd
        end
        vim.ui.select(Popup.session_menu.choices_list(), {
            prompt = 'Select a project from your session:',
            format_item = function(item) ---@param item string
                return vim.fn.isdirectory(item) == 1 and (item .. '/') or item
            end,
        }, function(item)
            if not item then
                return
            end
            if not in_list(Popup.session_menu.choices_list(), item) then
                error('Bad selection!', ERROR)
            end
            local choices = Popup.session_menu.choices()
            local op = choices[item]
            if not (op and vim.is_callable(op)) then
                error('Bad selection!', ERROR)
            end

            op(item, only_cd, false)
        end)
    end,
    choices = function()
        local sessions = require('project.utils.history').session_projects
        local choices = {
            ['Exit'] = function(_, _, _) end,
        }
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
