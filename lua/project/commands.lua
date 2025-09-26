---@alias ProjectCmdFun fun(ctx?: vim.api.keyset.create_user_command.command_args)
---@alias CompletorFun fun(a?: string, l?: string, p?: integer): string[]
---@alias Project.CMD
---|{ desc: string, name: string, bang: boolean, complete?: string|CompletorFun, nargs?: string|integer }
---|ProjectCmdFun

---@class Project.Commands.Spec
---@field callback fun(ctx?: vim.api.keyset.create_user_command.command_args)
---@field name string
---@field desc string
---@field complete? string|CompletorFun
---@field bang? boolean
---@field nargs? string|integer

local MODSTR = 'project.commands'
local ERROR = vim.log.levels.ERROR
local INFO = vim.log.levels.INFO
local in_list = vim.list_contains
local curr_buf = vim.api.nvim_get_current_buf
local vim_has = require('project.utils.util').vim_has

---@type { create_user_commands: (fun()), new: fun(spec: Project.Commands.Spec) }|table<string, Project.CMD>
local M = {}

---@param spec Project.Commands.Spec
function M.new(spec)
    if vim_has('nvim-0.11') then
        vim.validate('spec', spec, 'table', false, 'Project.Commands.Spec')
    else
        vim.validate({ spec = { spec, 'table' } })
    end

    if vim.tbl_isempty(spec) then
        error(('(%s.new): Empty command spec!'):format(MODSTR), ERROR)
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
    M[spec.name] = setmetatable({}, {
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

M.new({
    name = 'Project',
    callback = function(ctx)
        require('project.popup').open_menu(ctx.fargs)
    end,
    desc = 'Run the main project.nvim UI',
    nargs = '*',
    bang = true,
})

M.new({
    name = 'ProjectDelete',
    callback = function(ctx)
        if not ctx or vim.tbl_isempty(ctx.fargs) then
            require('project.popup').delete_menu()
            return
        end

        local recent = require('project.utils.history').get_recent_projects()
        if not recent then
            return
        end

        local force = ctx.bang ~= nil and ctx.bang or false
        for _, v in ipairs(ctx.fargs) do
            local path = vim.fn.fnamemodify(v, ':p')
            if path:sub(-1) == '/' then ---HACK: Getting rid of trailing `/` in string
                path = path:sub(1, path:len() - 1)
            end
            if not (force or in_list(recent, path) or path ~= '') then
                error(('(:ProjectDelete): Could not delete `%s`, aborting'):format(path), ERROR)
            end
            if vim.list_contains(recent, path) then
                require('project.utils.history').delete_project(path)
            end
        end
    end,
    desc = 'Deletes the projects given as args, assuming they are valid. No args open a popup',
    nargs = '*',
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

M.new({
    name = 'ProjectConfig',
    callback = function()
        local cfg = require('project').get_config()
        vim.notify(vim.inspect(cfg), INFO)
    end,
    desc = 'Prints out the current configuratiion for `project.nvim`',
})

M.new({
    name = 'ProjectFzf',
    callback = function()
        require('project.extensions.fzf-lua').run_fzf_lua()
    end,
    desc = 'Run project.nvim through Fzf-Lua (assuming you have it installed)',
})

M.new({
    name = 'ProjectAdd',
    callback = function(ctx)
        ---@type vim.ui.input.Opts
        local opts = {
            prompt = 'Input a valid path to the project:',
            completion = 'dir',
        }
        if ctx and ctx.bang ~= nil then
            if ctx.bang then
                opts.default = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(curr_buf()), ':p:h')
            end
        end

        vim.ui.input(opts, require('project.popup').prompt_project)
    end,
    desc = 'Prompt to add the current directory to the project history',
    bang = true,
})

M.new({
    name = 'ProjectRoot',
    callback = function(ctx)
        local verbose = ctx.bang ~= nil and ctx.bang or false
        require('project.api').on_buf_enter(verbose)
    end,
    desc = 'Sets the current project root to the current CWD',
    bang = true,
})

M.new({
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

M.new({
    name = 'ProjectTelescope',
    callback = function()
        if vim.g.project_telescope_loaded == 1 then
            require('telescope._extensions.projects').projects()
        end
    end,
    desc = 'Telescope shortcut for project.nvim picker',
})

function M.create_user_commands()
    vim.api.nvim_create_user_command(M.Project.name, function(ctx)
        M.Project(ctx)
    end, {
        desc = M.Project.desc,
        nargs = M.Project.nargs,
        bang = M.Project.bang,
    })
    vim.api.nvim_create_user_command(M.ProjectAdd.name, function(ctx)
        M.ProjectAdd(ctx)
    end, {
        bang = M.ProjectAdd.bang,
        desc = M.ProjectAdd.desc,
    })
    vim.api.nvim_create_user_command(M.ProjectConfig.name, function()
        M.ProjectConfig()
    end, {
        desc = M.ProjectConfig.desc,
    })
    vim.api.nvim_create_user_command(M.ProjectDelete.name, function(ctx)
        M.ProjectDelete(ctx)
    end, {
        desc = M.ProjectDelete.desc,
        bang = M.ProjectDelete.bang,
        nargs = M.ProjectDelete.nargs,
        complete = M.ProjectDelete.complete,
    })
    vim.api.nvim_create_user_command(M.ProjectRoot.name, function(ctx)
        M.ProjectRoot(ctx)
    end, {
        bang = M.ProjectRoot.bang,
        desc = M.ProjectRoot.desc,
    })
    vim.api.nvim_create_user_command(M.ProjectSession.name, function()
        M.ProjectSession()
    end, {
        desc = M.ProjectSession.desc,
    })
    vim.api.nvim_create_user_command(M.ProjectTelescope.name, function()
        M.ProjectTelescope()
    end, {
        desc = M.ProjectTelescope.desc,
    })
    if require('project.config').options.fzf_lua.enabled then
        vim.api.nvim_create_user_command(M.ProjectFzf.name, function()
            M.ProjectFzf()
        end, {
            desc = M.ProjectFzf.desc,
        })
    end
end

return M
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
