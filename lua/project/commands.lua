local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local INFO = vim.log.levels.INFO

local vim_has = require('project.utils.util').vim_has

---@class Project.Commands.Spec
---@field name string
---@field callback fun(ctx?: vim.api.keyset.create_user_command.command_args)
---@field desc string
---@field complete? fun(arg?: string, line?: string, pos?: integer): string[]

---@alias Project.CMD
---|{ name: string, desc: string, complete?: fun(arg?: string, line?: string, pos?: integer): string[] }
---|fun(ctx?: vim.api.keyset.create_user_command.command_args)

---@class Project.CMDS
---@field new fun(self: Project.Commands, spec: Project.Commands.Spec)

---@alias Project.Commands
---|Project.CMDS
---|table<string, Project.CMD>

---@type Project.Commands
local Command = {}

---@param self Project.Commands
---@param spec Project.Commands.Spec
function Command:new(spec)
    if vim_has('nvim-0.11') then
        vim.validate('spec', spec, 'table', false, 'Project.Commands.Spec')
    else
        vim.validate({ spec = { spec, 'table' } })
    end

    local callback = spec.callback

    ---@type Project.CMD
    local T = { name = spec.name, desc = spec.desc }

    if spec.complete and vim.is_callable(spec.complete) then
        T.complete = spec.complete
    end

    self[spec.name] = setmetatable(T, {
        __index = Command,

        ---@param ctx? vim.api.keyset.create_user_command.command_args
        __call = function(_, ctx)
            if ctx then
                callback(ctx)
                return
            end

            callback()
        end,
    })
end

Command:new({
    name = 'ProjectAdd',
    callback = function(ctx)
        local quiet = ctx.bang ~= nil and ctx.bang or false
        require('project.api').add_project_manually(not quiet)
    end,
    desc = 'Adds the current CWD project to the Project History',
})

Command:new({
    name = 'ProjectDelete',
    callback = function(ctx)
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
    desc = 'Deletes the projects given as args, assuming they are valid',

    ---@param line string
    complete = function(_, line)
        local recent = require('project.api').get_recent_projects()
        local input = vim.split(line, '%s+')
        local prefix = input[#input]

        return vim.tbl_filter(function(cmd) ---@param cmd string
            return vim.startswith(cmd, prefix)
        end, recent)
    end,
})

Command:new({
    name = 'ProjectConfig',
    callback = function()
        local cfg = require('project').get_config()
        vim.notify(vim.inspect(cfg), INFO)
    end,
    desc = 'Prints out the current configuratiion for `project.nvim`',
})

Command:new({
    name = 'ProjectFzf',
    callback = function()
        require('project').run_fzf_lua()
    end,
    desc = 'Run project.nvim through Fzf-Lua (assuming you have it installed)',
})

Command:new({
    name = 'ProjectRecents',
    callback = function()
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
    end,
    desc = 'Prints out the recent `project.nvim` projects',
})

Command:new({
    name = 'ProjectRoot',
    callback = function(ctx)
        local verbose = ctx.bang ~= nil and ctx.bang or false
        require('project.api').on_buf_enter(verbose)
    end,
    desc = 'Sets the current project root to the current CWD',
})

Command:new({
    name = 'ProjectSession',
    callback = function()
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
    end,
    desc = 'Prints out the current `project.nvim` projects session',
})

Command:new({
    name = 'ProjectTelescope',
    callback = function()
        require('telescope._extensions.projects').projects()
    end,
    desc = 'Telescope shortcut for project.nvim picker',
})

return Command

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
