local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local INFO = vim.log.levels.INFO

---@class Project.Commands
local M = {}

---@class Project.Commands.Completions
M.completions = {}

---CREDITS: @kuator
---@param _ string
---@param line string
---@return string[]
function M.completions.ProjectDelete(_, line)
    local recent = require('project.api').get_recent_projects()
    local input = vim.split(line, '%s+')
    local prefix = input[#input]

    return vim.tbl_filter(function(cmd) ---@param cmd string
        return vim.startswith(cmd, prefix)
    end, recent)
end

---@param ctx vim.api.keyset.create_user_command.command_args
function M.ProjectAdd(ctx)
    local verbose = ctx.bang ~= nil and ctx.bang or false
    require('project.api').add_project_manually(verbose)
end

function M.ProjectConfig()
    local cfg = require('project').get_config()
    vim.notify(vim.inspect(cfg), INFO)
end

---@param ctx vim.api.keyset.create_user_command.command_args
function M.ProjectDelete(ctx)
    local bang = ctx.bang ~= nil and ctx.bang or false

    for _, v in next, ctx.fargs do
        local path = vim.fn.fnamemodify(v, ':p')
        local recent = require('project.api').get_recent_projects()

        ---HACK: Getting rid of trailing `/` in string
        if path:sub(-1) == '/' then
            path = path:sub(1, path:len() - 1)
        end

        ---If `:ProjectDelete` isn't called with bang `!`, abort on
        ---anything that isn't in recent projects
        if not (bang or vim.tbl_contains(recent, path) or path ~= '') then
            error(('(:ProjectDelete): Could not delete `%s`, aborting'):format(path), ERROR)
        end

        if vim.list_contains(recent, path) then
            require('project.api').delete_project(path)
        end
    end
end

function M.ProjectFzf()
    require('project').run_fzf_lua()
end

function M.ProjectRecents()
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
end

---@param ctx vim.api.keyset.create_user_command.command_args
function M.ProjectRoot(ctx)
    local verbose = ctx.bang ~= nil and ctx.bang or false
    require('project.api').on_buf_enter(verbose)
end

function M.ProjectTelescope()
    require('telescope._extensions.projects').projects()
end

return M

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
