---@class Project.Popup.SelectSpec
---@field choices fun(): table<string, function>
---@field choices_list fun(): string[]
---@field callback ProjectCmdFun

-- local MODSTR = 'project.popup'

local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local in_list = vim.list_contains

local Util = require('project.utils.util')
local History = require('project.utils.history')
local Path = require('project.utils.path')
local Config = require('project.config')
local exists = Path.exists
local get_recent_projects = History.get_recent_projects

---@class Project.Popup
local Popup = {}

---@class Project.Popup.Select
Popup.select = {}

---@param opts Project.Popup.SelectSpec
---@return { choices: (fun(): table<string, ProjectCmdFun>), choices_list: (fun(): string[]) }|ProjectCmdFun
function Popup.select:new(opts)
    ---@type { choices: (fun(): table<string, ProjectCmdFun>), choices_list: (fun(): string[]) }|ProjectCmdFun
    local T = setmetatable({
        choices = opts.choices,
        choices_list = opts.choices_list,
    }, {
        __index = Popup.select,

        ---@param ctx? vim.api.keyset.create_user_command.command_args
        __call = function(_, ctx)
            if ctx then
                opts.callback(ctx)
                return
            end

            opts.callback()
        end,
    })

    return T
end

---@param input string?
function Popup.prompt_project(input)
    local Api = require('project.api')
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

    local recent = require('project.utils.history').get_recent_projects()
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
        }, function(item, _)
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
                require('project.commands').ProjectNew()
            end,
            ['Delete A Project'] = function()
                require('project.commands').ProjectDelete()
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
        if vim.g.telescope_loaded == 1 then
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
            'Show Config',
            'Run Checkhealth',
        }

        if vim.g.telescope_loaded == 1 then
            table.insert(res_list, 'Open Telescope Picker')
        end
        if Config.options.fzf_lua.enabled then
            table.insert(res_list, 'Open Fzf-Lua Picker')
        end
        if Config.options.log.enabled then
            table.insert(res_list, 'Open Log')
            table.insert(res_list, 'Clear Log')
        end
        table.insert(res_list, 'Open Help Docs')
        table.insert(res_list, 'Exit')

        return res_list
    end,
})

return Popup

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
