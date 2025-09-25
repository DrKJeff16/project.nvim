---@class Project.Popup.SelectSpec
---@field choices table<string, function>
---@field choices_list string[]
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

---@class Project.Popup
local Popup = {}

---@class Project.Popup.Select
Popup.select = {}

---@param opts Project.Popup.SelectSpec
---@return { choices: table<string, ProjectCmdFun>, choices_list: string[] }|ProjectCmdFun
function Popup.select:new(opts)
    ---@type { choices: table<string, ProjectCmdFun>, choices_list: string[] }|ProjectCmdFun
    local T = setmetatable({}, {
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

    T.choices = opts.choices
    T.choices_list = opts.choices_list

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

    if Api.current_project == input or in_list(History.get_recent_projects(), input) then
        vim.notify('Already added that directory!', WARN)
        return
    end

    Api.set_pwd(input, 'prompt')
    History.write_history()
end

Popup.open_menu = Popup.select:new({
    callback = function(ctx)
        vim.ui.select(Popup.open_menu.choices_list, {
            prompt = 'Select an operation:',
        }, function(item, _)
            if not in_list(Popup.open_menu.choices_list, item) then
                error('Bad selection!', ERROR)
            end

            local op = Popup.open_menu.choices[item]
            if not (op and vim.is_callable(op)) then
                error('Bad selection!', ERROR)
            end

            if ctx then
                op(ctx)
                return
            end

            op()
        end)
    end,
    choices = (function()
        ---@type table<string, ProjectCmdFun>
        local res = {
            ['New Project'] = function(ctx)
                if vim.tbl_isempty(ctx.fargs) then
                    require('project.commands').ProjectNew()
                    return
                end

                require('project.commands').ProjectNew(ctx)
            end,
            ['Delete Project'] = function() end,
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
    end)(),
    choices_list = (function()
        ---@type string[]
        local res_list = {
            'New Project',
            'Delete Project',
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
    end)(),
})

return Popup

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
