local fmt = string.format
local copy = vim.deepcopy

local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local INFO = vim.log.levels.INFO

vim.api.nvim_create_user_command('ProjectRoot', function(ctx)
    local bang = ctx.bang ~= nil and ctx.bang or false
    local Api = require('project.api')

    Api.on_buf_enter(bang)
end, {
    bang = true,
})

vim.api.nvim_create_user_command('ProjectAdd', function(ctx)
    local bang = ctx.bang ~= nil and ctx.bang or false
    local Api = require('project.api')

    Api.add_project_manually(bang)
end, {
    bang = true,
})

---`:ProjectConfig`
vim.api.nvim_create_user_command('ProjectConfig', function()
    local cfg = require('project').get_config()
    local inspect = vim.inspect

    vim.notify(inspect(cfg))
end, {})

vim.api.nvim_create_user_command('ProjectRecents', function()
    local Api = require('project.api')
    local reverse = require('project.utils.util').reverse
    local recent_proj = Api.get_recent_projects()

    if recent_proj == nil or vim.tbl_isempty(recent_proj) then
        vim.notify('{}', WARN)
    end

    ---@type string[]
    recent_proj = reverse(copy(recent_proj))

    local len, msg = #recent_proj, ''

    for k, v in next, recent_proj do
        msg = fmt('%s %s. %s', msg, k, v)

        msg = k < len and fmt('%s\n', msg) or msg
    end

    vim.notify(msg, INFO)
end, {})

vim.api.nvim_create_user_command('ProjectDelete', function(ctx)
    local bang = ctx.bang ~= nil and ctx.bang or false

    for _, v in next, ctx.fargs do
        local Api = require('project.api')
        local path = vim.fn.fnamemodify(v, ':p')
        local recent = Api.get_recent_projects()

        ---HACK: Getting rid of trailing `/` in string
        if path:sub(-1) == '/' then
            path = path:sub(1, string.len(path) - 1)
        end

        ---If `:ProjectDelete` isn't called with bang `!`, abort on
        ---anything that isn't in recent projects
        if not (bang or vim.tbl_contains(recent, path) or path ~= '') then
            error(fmt('(:ProjectDelete): Could not delete `%s`, aborting', path), ERROR)
        end

        if vim.tbl_contains(recent, path) then
            Api.delete_project(path)
        end
    end
end, {
    desc = 'Delete the projects given as args, assuming they are valid',
    bang = true,
    nargs = '+',

    ---@return string[]|table
    complete = function(_, _, _)
        ---TODO: Structure completions for `:ProjectDelete`
        local Api = require('project.api')

        return Api.get_recent_projects() or {}
    end,
})
