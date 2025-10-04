---@alias ProjectCmdFun fun(ctx?: vim.api.keyset.create_user_command.command_args)
---@alias CompletorFun fun(a?: string, l?: string, p?: integer): string[]
---@alias Project.CMD
---|{ desc: string, name: string, bang: boolean, complete?: string|CompletorFun, nargs?: string|integer }
---|ProjectCmdFun

---@class Project.Commands.Spec
---@field callback fun(ctx?: vim.api.keyset.create_user_command.command_args)
---@field name string
---@field desc string
---@field with_ctx? boolean
---@field complete? string|CompletorFun
---@field bang? boolean
---@field nargs? string|integer

local MODSTR = 'project.commands'
local ERROR = vim.log.levels.ERROR
local in_list = vim.list_contains
local curr_buf = vim.api.nvim_get_current_buf
local vim_has = require('project.utils.util').vim_has

---@type table<string, Project.CMD>
local M = {}

---@type fun(specs: Project.Commands.Spec[])
function M.new(specs)
    if vim_has('nvim-0.11') then
        vim.validate('specs', specs, 'table', false, 'Project.Commands.Spec[]')
    else
        vim.validate({ specs = { specs, 'table' } })
    end
    if vim.tbl_isempty(specs) then
        error(('(%s.new): Empty command spec!'):format(MODSTR), ERROR)
    end

    for _, spec in ipairs(specs) do
        ---@type { name: string, desc: string, bang: boolean, complete?: string|CompletorFun, nargs?: string|integer }
        local T = {
            name = spec.name,
            desc = spec.desc,
            bang = spec.bang ~= nil and spec.bang or false,
        }
        local opts = {
            desc = spec.desc,
            bang = spec.bang ~= nil and spec.bang or false,
        }
        if spec.nargs ~= nil then
            T.nargs = spec.nargs
            opts.nargs = spec.nargs
        end
        if spec.complete and vim.is_callable(spec.complete) then
            T.complete = spec.complete
            opts.complete = spec.complete
        end
        M[spec.name] = setmetatable({}, {
            ---@param k string
            __index = function(_, k)
                return T[k]
            end,
            __tostring = function()
                return T.desc
            end,
            __call = function(_, ctx) ---@param ctx? vim.api.keyset.create_user_command.command_args
                if ctx then
                    spec.callback(ctx)
                    return
                end
                spec.callback()
            end,
        })
        vim.api.nvim_create_user_command(M[spec.name].name, function(ctx)
            local with_ctx = spec.with_ctx ~= nil and spec.with_ctx or false
            local cmd = M[spec.name]
            if with_ctx then
                cmd(ctx)
                return
            end
            cmd()
        end, opts)
    end
end

---@type function
function M.create_user_commands()
    M.new({
        {
            name = 'Project',
            with_ctx = true,
            callback = function(ctx)
                require('project.popup').open_menu(ctx.fargs)
            end,
            desc = 'Run the main project.nvim UI',
            nargs = '*',
            bang = true,
        },
        {
            name = 'ProjectAdd',
            with_ctx = true,
            callback = function(ctx)
                ---@type vim.ui.input.Opts
                local opts = {
                    prompt = 'Input a valid path to the project:',
                    completion = 'dir',
                }
                if ctx and ctx.bang ~= nil then
                    if ctx.bang then
                        local bufnr = curr_buf()
                        opts.default = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':p:h')
                    end
                end

                vim.ui.input(opts, require('project.popup').prompt_project)
            end,
            desc = 'Prompt to add the current directory to the project history',
            bang = true,
        },
        {
            name = 'ProjectConfig',
            callback = function()
                local Config = require('project.config')
                if not Config.conf_loc then
                    Config.open_win()
                    return
                end
                Config.close_win()
            end,
            desc = 'Prints out the current configuratiion for `project.nvim`',
        },
        {
            name = 'ProjectDelete',
            with_ctx = true,
            callback = function(ctx)
                if not ctx or vim.tbl_isempty(ctx.fargs) then
                    require('project.popup').delete_menu()
                    return
                end

                local Log = require('project.utils.log')
                local recent = require('project.utils.history').get_recent_projects()
                if not recent then
                    Log.error('(:ProjectDelete): No recent projects!')
                    return
                end

                local force = ctx.bang ~= nil and ctx.bang or false
                for _, v in ipairs(ctx.fargs) do
                    local path = vim.fn.fnamemodify(v, ':p')
                    if path:sub(-1) == '/' then ---HACK: Getting rid of trailing `/` in string
                        path = path:sub(1, path:len() - 1)
                    end
                    if not (force or in_list(recent, path) or path ~= '') then
                        Log.error(
                            ('(:ProjectDelete): Could not delete `%s`, aborting'):format(path)
                        )
                        error(
                            ('(:ProjectDelete): Could not delete `%s`, aborting'):format(path),
                            ERROR
                        )
                    end
                    if vim.list_contains(recent, path) then
                        require('project.utils.history').delete_project(path)
                    end
                end
            end,
            desc = 'Deletes the projects given as args, assuming they are valid. No args open a popup',
            nargs = '*',
            bang = true,
            complete = function(_, line) ---@param line string
                local recent = require('project.utils.history').get_recent_projects()
                local input = vim.split(line, '%s+')
                local prefix = input[#input]
                return vim.tbl_filter(function(cmd) ---@param cmd string
                    return vim.startswith(cmd, prefix)
                end, recent)
            end,
        },
        {
            name = 'ProjectFzf',
            callback = function()
                require('project.extensions.fzf-lua').run_fzf_lua()
            end,
            desc = 'Run project.nvim through Fzf-Lua (assuming you have it installed)',
        },
        {
            name = 'ProjectHistory',
            with_ctx = true,
            callback = function(ctx)
                local bang = ctx.bang ~= nil and ctx.bang or false
                if not bang then
                    require('project.utils.history').open_win()
                    return
                end
                require('project.utils.history').close_win()
            end,
            desc = 'Run project.nvim through Fzf-Lua (assuming you have it installed)',
            bang = true,
        },
        {
            name = 'ProjectRecents',
            callback = function()
                require('project.popup').recents_menu()
            end,
            desc = 'Opens a menu to select a project from your history',
        },
        {
            name = 'ProjectRoot',
            with_ctx = true,
            callback = function(ctx)
                local verbose = ctx.bang ~= nil and ctx.bang or false
                require('project.api').on_buf_enter(verbose)
            end,
            desc = 'Sets the current project root to the current CWD',
            bang = true,
        },
        {
            name = 'ProjectSession',
            with_ctx = true,
            callback = function(ctx)
                require('project.popup').session_menu(ctx)
            end,
            desc = 'Opens a menu to switch between sessions',
            bang = true,
        },
        {
            name = 'ProjectTelescope',
            callback = function()
                if vim.g.project_telescope_loaded == 1 then
                    require('telescope._extensions.projects').projects()
                end
            end,
            desc = 'Telescope shortcut for project.nvim picker',
        },
    })
end

return M
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
