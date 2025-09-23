local MODSTR = 'project.commands'
local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local INFO = vim.log.levels.INFO

local vim_has = require('project.utils.util').vim_has

---@alias CompletorFun fun(a?: string, l?: string, p?: integer): string[]

---@class Project.Commands.Spec
---@field name string
---@field callback fun(ctx?: vim.api.keyset.create_user_command.command_args)
---@field desc string
---@field complete? string|CompletorFun
---@field bang? boolean
---@field nargs? string|integer

---@alias Project.CMD
---|{ name: string, desc: string, bang: boolean, complete?: string|CompletorFun, nargs?: any }
---|fun(ctx?: vim.api.keyset.create_user_command.command_args)

---@class Project.Commands
---@field new fun(spec: Project.Commands.Spec)
---@field create_user_commands fun()

---@type Project.Commands|table<string, Project.CMD>
local Commands = {}

---@param spec Project.Commands.Spec
function Commands.new(spec)
    if vim_has('nvim-0.11') then
        vim.validate('spec', spec, 'table', false, 'Project.Commands.Spec')
    else
        vim.validate({ spec = { spec, 'table' } })
    end

    if vim.tbl_isempty(spec) then
        error(('(%s.new): Empty command spec!'):format(MODSTR), ERROR)
    end

    if vim_has('nvim-0.11') then
        vim.validate('name', spec.name, 'string', false)
        vim.validate('callback', spec.callback, 'function', false)
        vim.validate('desc', spec.desc, 'string', false)
        vim.validate('bang', spec.bang, 'boolean', true, 'boolean?')
        vim.validate('nargs', spec.nargs, { 'string', 'number' }, true, '(string|integer)?')
        vim.validate(
            'complete',
            spec.complete,
            { 'function', 'string' },
            true,
            '(string|CompletorFun)?'
        )
    else
        vim.validate({
            name = { spec.name, 'string' },
            callback = { spec.callback, 'function' },
            desc = { spec.desc, 'string' },
            bang = { spec.bang, { 'string', 'nil' } },
            nargs = { spec.nargs, { 'string', 'number', 'nil' } },
            complete = { spec.complete, { 'string', 'function', 'nil' } },
        })
    end

    ---@type { name: string, desc: string, bang: boolean, complete?: string|CompletorFun, nargs?: string|integer }
    local T = {
        name = spec.name,
        desc = spec.desc,
        bang = spec.bang ~= nil and spec.bang or false,
    }

    if spec.nargs ~= nil then
        T.nargs = spec.nargs
    end

    if spec.complete and vim.is_callable(spec.complete) then
        T.complete = spec.complete
    end

    Commands[spec.name] = setmetatable({}, {
        ---@param k string
        __index = function(_, k)
            return T[k]
        end,

        __tostring = function()
            return T.desc
        end,

        ---@param ctx? vim.api.keyset.create_user_command.command_args
        __call = function(_, ctx)
            if ctx then
                spec.callback(ctx)
                return
            end

            spec.callback()
        end,
    })
end

Commands.new({
    name = 'ProjectAdd',
    callback = function(ctx)
        local quiet = ctx.bang ~= nil and ctx.bang or false
        require('project.api').add_project_manually(not quiet)
    end,
    desc = 'Adds the current CWD project to the Project History',
    bang = true,
})

Commands.new({
    name = 'ProjectDelete',
    callback = function(ctx)
        local force = ctx.bang ~= nil and ctx.bang or false
        local recent = require('project.utils.history').get_recent_projects()

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
                require('project.utils.history').delete_project(path)
            end
        end
    end,
    desc = 'Deletes the projects given as args, assuming they are valid',
    nargs = '+',
    bang = true,

    ---@param line string
    complete = function(_, line)
        local recent = require('project.utils.history').get_recent_projects()
        local input = vim.split(line, '%s+')
        local prefix = input[#input]

        return vim.tbl_filter(function(cmd) ---@param cmd string
            return vim.startswith(cmd, prefix)
        end, recent)
    end,
})

Commands.new({
    name = 'ProjectConfig',
    callback = function()
        local cfg = require('project').get_config()
        vim.notify(vim.inspect(cfg), INFO)
    end,
    desc = 'Prints out the current configuratiion for `project.nvim`',
})

Commands.new({
    name = 'ProjectFzf',
    callback = function()
        require('project.extensions.fzf-lua').run_fzf_lua()
    end,
    desc = 'Run project.nvim through Fzf-Lua (assuming you have it installed)',
})

Commands.new({
    name = 'ProjectRecents',
    callback = function()
        local recent = require('project.utils.history').get_recent_projects()
        local reverse = require('project.utils.util').reverse

        if recent == nil or vim.tbl_isempty(recent) then
            vim.notify('{}', WARN)
            return
        end

        ---@type string[]
        recent = reverse(vim.deepcopy(recent))

        local len, msg = #recent, ''

        for k, v in ipairs(recent) do
            msg = ('%s %s. %s'):format(msg, k, v) .. (k < len and ('%s\n'):format(msg) or '')
        end

        vim.notify(msg, INFO)
    end,
    desc = 'Prints out the recent `project.nvim` projects',
})

Commands.new({
    name = 'ProjectRoot',
    callback = function(ctx)
        local verbose = ctx.bang ~= nil and ctx.bang or false
        require('project.api').on_buf_enter(verbose)
    end,
    desc = 'Sets the current project root to the current CWD',
    bang = true,
})

Commands.new({
    name = 'ProjectSession',
    callback = function()
        local session = require('project.utils.history').session_projects
        if vim.tbl_isempty(session) then
            vim.notify('No sessions available!', ERROR)
            return
        end

        local len = #session
        local msg = ''

        for i, proj in ipairs(session) do
            msg = msg .. (len ~= i and '%s. %s\n' or '%s. %s'):format(i, proj)
        end

        vim.notify(msg, INFO)
    end,
    desc = 'Prints out the current `project.nvim` projects session',
})

Commands.new({
    name = 'ProjectTelescope',
    callback = function()
        if vim.g.project_telescope_loaded == 1 then
            require('telescope._extensions.projects').projects()
        end
    end,
    desc = 'Telescope shortcut for project.nvim picker',
})

function Commands.create_user_commands()
    ---`:ProjectAdd`
    vim.api.nvim_create_user_command('ProjectAdd', function(ctx)
        Commands.ProjectAdd(ctx)
    end, {
        bang = Commands.ProjectAdd.bang,
        desc = Commands.ProjectAdd.desc,
    })

    ---`:ProjectConfig`
    vim.api.nvim_create_user_command('ProjectConfig', function()
        Commands.ProjectConfig()
    end, {
        desc = Commands.ProjectConfig.desc,
    })

    ---`:ProjectDelete`
    vim.api.nvim_create_user_command('ProjectDelete', function(ctx)
        Commands.ProjectDelete(ctx)
    end, {
        desc = Commands.ProjectDelete.desc,
        bang = Commands.ProjectDelete.bang,
        nargs = Commands.ProjectDelete.nargs,
        complete = Commands.ProjectDelete.complete,
    })

    ---`:ProjectRecents`
    vim.api.nvim_create_user_command('ProjectRecents', function()
        Commands.ProjectRecents()
    end, {
        desc = Commands.ProjectRecents.desc,
    })

    ---`:ProjectRoot`
    vim.api.nvim_create_user_command('ProjectRoot', function(ctx)
        Commands.ProjectRoot(ctx)
    end, {
        bang = Commands.ProjectRoot.bang,
        desc = Commands.ProjectRoot.desc,
    })

    ---`:ProjectSession`
    vim.api.nvim_create_user_command('ProjectSession', function()
        Commands.ProjectSession()
    end, {
        desc = Commands.ProjectSession.desc,
    })

    if require('project.config').options.fzf_lua.enabled then
        ---`:ProjectFzf`
        vim.api.nvim_create_user_command('ProjectFzf', function()
            Commands.ProjectFzf()
        end, {
            desc = Commands.ProjectFzf.desc,
        })
    end

    ---`:ProjectTelescope`
    vim.api.nvim_create_user_command('ProjectTelescope', function()
        Commands.ProjectTelescope()
    end, {
        desc = Commands.ProjectTelescope.desc,
    })
end

return Commands

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
