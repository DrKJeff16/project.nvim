local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local INFO = vim.log.levels.INFO

local vim_has = require('project.utils.util').vim_has

---@class ProjectCommand
---@field complete? fun(arg?: string, line?: string, pos?: integer)
---@field desc string
local Command = {}

---@param func fun(ctx?: vim.api.keyset.create_user_command.command_args)
---@param desc string
---@param completor? fun(arg?: string, line?: string, pos?: integer): string[]
---@return ProjectCommand|fun(ctx?: vim.api.keyset.create_user_command.command_args)
function Command.new(func, desc, completor)
    if vim_has('nvim-0.11') then
        vim.validate(
            'func',
            func,
            'function',
            false,
            'fun(ctx?: vim.api.keyset.create_user_command.command_args)'
        )
        vim.validate('desc', desc, 'string', false)
        vim.validate(
            'completor',
            completor,
            'function',
            true,
            'fun(arg?: string, line?: string, pos?: integer): string[]'
        )
    else
        vim.validate({
            func = { func, 'function' },
            desc = { desc, 'string' },
            completor = { completor, { 'function', 'nil' } },
        })
    end

    ---@type ProjectCommand|fun(ctx?: vim.api.keyset.create_user_command.command_args)
    local self = setmetatable({}, {
        __index = Command,

        ---@param ctx? vim.api.keyset.create_user_command.command_args
        __call = function(_, ctx)
            if ctx then
                func(ctx)
                return
            end

            func()
        end,
    })

    self.desc = desc

    if completor and vim.is_callable(completor) then
        self.complete = completor
    end

    return self
end

---@class Project.Commands
local M = {}

M.ProjectAdd = Command.new(function(ctx)
    local quiet = ctx.bang ~= nil and ctx.bang or false
    require('project.api').add_project_manually(not quiet)
end, 'Adds the current CWD project to the Project History')

M.ProjectDelete = Command.new(
    function(ctx)
        local force = ctx.bang ~= nil and ctx.bang or false
        local recent = require('project.api').get_recent_projects()

        if recent == nil then
            return
        end

        for _, v in ipairs(ctx.fargs) do
            local path = vim.fn.fnamemodify(v, ':p')

            ---HACK: Getting rid of trailing `/` in string
            if path:sub(-1) == '/' then
                path = path:sub(1, path:len() - 1)
            end

            ---If `:ProjectDelete` isn't called with bang `!`, abort on
            ---anything that isn't in recent projects
            if not (force or vim.list_contains(recent, path) or path ~= '') then
                error(('(:ProjectDelete): Could not delete `%s`, aborting'):format(path), ERROR)
            end

            if vim.list_contains(recent, path) then
                require('project.api').delete_project(path)
            end
        end
    end,
    'Deletes the projects given as args, assuming they are valid',
    function(_, line)
        local recent = require('project.api').get_recent_projects()
        local input = vim.split(line, '%s+')
        local prefix = input[#input]

        return vim.tbl_filter(function(cmd) ---@param cmd string
            return vim.startswith(cmd, prefix)
        end, recent)
    end
)

M.ProjectConfig = Command.new(function()
    local cfg = require('project').get_config()
    vim.notify(vim.inspect(cfg), INFO)
end, 'Prints out the current configuratiion for `project.nvim`')

M.ProjectFzf = Command.new(function()
    require('project').run_fzf_lua()
end, 'Run project.nvim through Fzf-Lua (assuming you have it installed)')

M.ProjectRecents = Command.new(function()
    local recent_proj = require('project.api').get_recent_projects()
    local reverse = require('project.utils.util').reverse

    if recent_proj == nil or vim.tbl_isempty(recent_proj) then
        vim.notify('{}', WARN)
        return
    end

    ---@type string[]
    recent_proj = reverse(vim.deepcopy(recent_proj))

    local len, msg = #recent_proj, ''

    for k, v in ipairs(recent_proj) do
        msg = ('%s %s. %s'):format(msg, k, v) .. (k < len and ('%s\n'):format(msg) or '')
    end

    vim.notify(msg, INFO)
end, 'Prints out the recent `project.nvim` projects')

---@param ctx vim.api.keyset.create_user_command.command_args
M.ProjectRoot = Command.new(function(ctx)
    local verbose = ctx.bang ~= nil and ctx.bang or false
    require('project.api').on_buf_enter(verbose)
end, 'Sets the current project root to the current CWD')

M.ProjectSession = Command.new(function()
    local session = require('project.utils.history').session_projects
    if vim.tbl_isempty(session) then
        vim.notify('No sessions available!', vim.log.levels.WARN)
        return
    end

    local len = #session
    local msg = ''

    for i, proj in ipairs(session) do
        msg = msg .. (len ~= i and '%s. %s\n' or '%s. %s'):format(i, proj)
    end
    vim.notify(msg, vim.log.levels.INFO)
end, 'Prints out the current `project.nvim` projects session')

M.ProjectTelescope = Command.new(function()
    require('telescope._extensions.projects').projects()
end, 'Telescope shortcut for project.nvim picker')

return M

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
