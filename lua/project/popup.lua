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

---@class Project.Popup
local Popup = {}

---@class Project.Popup.Select
Popup.select = {}

---@param opts Project.Popup.SelectSpec
---@return Project.Popup.Select|Project.Popup.SelectChoices|ProjectCmdFun
function Popup.select:new(opts)
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
        error(('(%s.select:new): Empty args for constructor!'):format(MODSTR), ERROR)
    end

    if vim_has('nvim-0.11') then
        vim.validate('choices', opts.choices, 'function', false, 'fun(): table<string, function>')
        vim.validate('choices_list', opts.choices_list, 'function', false, 'fun(): string[]')
        vim.validate(
            'callback',
            opts.callback,
            'function',
            false,
            'fun(ctx?: vim.api.keyset.create_user_command.command_args)'
        )
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

Popup.delete_menu = Popup.select:new({
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
            if not in_list(Popup.delete_menu.choices_list(), item) then
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

Popup.open_menu = Popup.select:new({
    callback = function()
        vim.ui.select(Popup.open_menu.choices_list(), {
            prompt = 'Select an operation:',
        }, function(item, _)
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
            ['New Project'] = function()
                require('project.commands').ProjectAdd()
            end,
            ['Delete A Project'] = function()
                Popup.delete_menu()
            end,
            ['Show Config'] = function()
                require('project.commands').ProjectConfig()
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
        table.insert(res_list, 'Run Checkhealth')
        table.insert(res_list, 'Open Help Docs')
        table.insert(res_list, 'Exit')

        return res_list
    end,
})

return Popup

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
