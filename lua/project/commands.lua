local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local INFO = vim.log.levels.INFO

local vim_has = require('project.utils.util').vim_has

---@class ProjectCommand
---@field complete? fun(arg?: string, line?: string, pos?: integer)
local Command = {}

---@param func fun(_, ctx?: vim.api.keyset.create_user_command.command_args)
---@param completor? fun(arg?: string, line?: string, pos?: integer): string[]
---@return ProjectCommand|fun(ctx?: vim.api.keyset.create_user_command.command_args)
function Command.new(func, completor)
    if vim_has('nvim-0.11') then
        vim.validate(
            'func',
            func,
            'function',
            false,
            'fun(_, ctx?: vim.api.keyset.create_user_command.command_args)'
        )
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
            completor = { completor, { 'function', 'nil' } },
        })
    end

    local self = setmetatable({}, {
        __index = Command,
        __call = func,
    })

    if completor and vim.is_callable(completor) then
        self.complete = completor
    end

    return self
end

---@class Project.Commands
local M = {}

M.ProjectAdd = Command.new(function(_, ctx)
    local quiet = ctx.bang ~= nil and ctx.bang or false
    require('project.api').add_project_manually(not quiet)
end)

M.ProjectDelete = Command.new(function(_, ctx)
    local force = ctx.bang ~= nil and ctx.bang or false
    local recent = require('project.api').get_recent_projects()

    if recent == nil then
        return
    end

    for _, v in next, ctx.fargs do
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
end, function(_, line)
    local recent = require('project.api').get_recent_projects()
    local input = vim.split(line, '%s+')
    local prefix = input[#input]

    return vim.tbl_filter(function(cmd) ---@param cmd string
        return vim.startswith(cmd, prefix)
    end, recent)
end)

M.ProjectConfig = Command.new(function(_)
    local cfg = require('project').get_config()
    vim.notify(vim.inspect(cfg), INFO)
end)

M.ProjectFzf = Command.new(function(_)
    require('project').run_fzf_lua()
end)

M.ProjectRecents = Command.new(function(_)
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
end)

---@param ctx vim.api.keyset.create_user_command.command_args
M.ProjectRoot = Command.new(function(_, ctx)
    local verbose = ctx.bang ~= nil and ctx.bang or false
    require('project.api').on_buf_enter(verbose)
end)

M.ProjectSession = Command.new(function(_)
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
end)

M.ProjectTelescope = Command.new(function(_)
    require('telescope._extensions.projects').projects()
end)

return M

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
