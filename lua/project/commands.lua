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

---@class Project.Commands
local Commands = {}

function Commands.new(specs) ---@type fun(specs: Project.Commands.Spec[])
    if vim_has('nvim-0.11') then
        vim.validate('specs', specs, 'table', false)
    else
        vim.validate({ specs = { specs, { 'table' } } })
    end
    if vim.tbl_isempty(specs) then
        vim.notify(('(%s.new): Empty command spec!'):format(MODSTR), ERROR)
        return
    end

    for _, spec in ipairs(specs) do
        if not (spec.callback and vim.is_callable(spec.callback)) then
            vim.notify(('(%s.new): Missing callback!'):format(MODSTR), ERROR)
            return
        end
        local bang = spec.bang ~= nil and spec.bang or false
        local T = { name = spec.name, desc = spec.desc, bang = bang }
        local opts = { desc = spec.desc, bang = bang }
        if spec.nargs ~= nil then
            T.nargs = spec.nargs
            opts.nargs = spec.nargs
        end
        if spec.complete and vim.is_callable(spec.complete) then
            T.complete = spec.complete
            opts.complete = spec.complete
        end
        Commands.cmds[spec.name] = setmetatable({}, {
            __index = function(_, k) ---@param k string
                return T[k]
            end,
            __tostring = function(_)
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
        vim.api.nvim_create_user_command(spec.name, function(ctx)
            local with_ctx = spec.with_ctx ~= nil and spec.with_ctx or false
            local cmd = Commands.cmds[spec.name]
            if with_ctx then
                cmd(ctx)
                return
            end
            cmd()
        end, opts)
    end
end

function Commands.create_user_commands() ---@type function
    Commands.new({
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
            with_ctx = true,
            callback = function(ctx)
                local Config = require('project.config')
                if ctx then
                    if ctx.bang ~= nil and ctx.bang then
                        Config.close_win()
                        return
                    end
                end
                if not Config.conf_loc then
                    Config.open_win()
                end
            end,
            desc = 'Prints out the current configuratiion for `project.nvim`',
            bang = true,
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
                        vim.notify(
                            ('(:ProjectDelete): Could not delete `%s`, aborting'):format(path),
                            ERROR
                        )
                        return
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
            name = 'ProjectHealth',
            with_ctx = false,
            callback = function()
                vim.cmd.checkhealth('project')
            end,
            desc = 'Run checkhealth for project.nvim',
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

---@type table<string, Project.CMD>
Commands.cmds = {}

return Commands
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
