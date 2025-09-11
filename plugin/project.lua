local fmt = string.format
local copy = vim.deepcopy

local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local INFO = vim.log.levels.INFO

local Util = require('project.utils.util')
local reverse = Util.reverse

vim.api.nvim_create_user_command('ProjectRoot', function(ctx)
    local verbose = ctx.bang ~= nil and ctx.bang or false
    require('project.api').on_buf_enter(verbose)
end, {
    bang = true,
    desc = 'Sets the current project root to the current CWD',
})

vim.api.nvim_create_user_command('ProjectAdd', function(ctx)
    local verbose = ctx.bang ~= nil and ctx.bang or false
    require('project.api').add_project_manually(verbose)
end, {
    bang = true,
    desc = 'Adds the current CWD project to the Project History',
})

---`:ProjectConfig`
vim.api.nvim_create_user_command('ProjectConfig', function()
    local cfg = require('project').get_config()

    vim.notify(vim.inspect(cfg), INFO)
end, {
    desc = 'Prints out the current configuratiion for `project.nvim`',
})

vim.api.nvim_create_user_command('ProjectRecents', function()
    local recent_proj = require('project.api').get_recent_projects()

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
end, {
    desc = 'Prints out the recent `project.nvim` projects',
})

vim.api.nvim_create_user_command('ProjectDelete', function(ctx)
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
            error(fmt('(:ProjectDelete): Could not delete `%s`, aborting', path), ERROR)
        end

        if vim.tbl_contains(recent, path) then
            require('project.api').delete_project(path)
        end
    end
end, {
    desc = 'Deletes the projects given as args, assuming they are valid',
    bang = true,
    nargs = '+',

    ---CREDITS: @kuator
    ---@param line string
    ---@return string[]
    complete = function(_, line)
        local recent = require('project.api').get_recent_projects()
        local input = vim.split(line, '%s+')
        local prefix = input[#input]

        return vim.tbl_filter(function(cmd)
            return vim.startswith(cmd, prefix)
        end, recent)
    end,
})

---Add `Fzf-Lua` command ONLY if it is installed
if Util.mod_exists('fzf-lua') then
    vim.api.nvim_create_user_command('ProjectFzf', function()
        require('project').run_fzf_lua()
    end, {
        desc = 'Run project.nvim through Fzf-Lua (assuming you have it installed)',
    })
end

---Add `Telescope` shortcut ONLY if it is installed and loaded
if Util.mod_exists('telescope') then
    vim.api.nvim_create_user_command('ProjectTelescope', function()
        require('telescope._extensions.projects').projects()
    end, {
        desc = 'Telescope shortcut for project.nvim picker',
    })
end
