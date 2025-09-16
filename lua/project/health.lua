local fmt = string.format
local uv = vim.uv or vim.loop

---@alias HistoryCheck { name: string, type: ('file'|'directory'), path: string }

local start = vim.health.start or vim.health.report_start
local ok = vim.health.ok or vim.health.report_ok
local info = vim.health.info or vim.health.report_info
local h_warn = vim.health.warn or vim.health.report_warn
local h_error = vim.health.error or vim.health.report_error

local empty = vim.tbl_isempty
local copy = vim.deepcopy
local in_tbl = vim.tbl_contains
local in_list = vim.list_contains

local Util = require('project.utils.util')
local Path = require('project.utils.path')
local History = require('project.utils.history')
local Config = require('project.config')
local Api = require('project.api')

local is_type = Util.is_type
local dedup = Util.dedup
local format_per_type = Util.format_per_type
local mod_exists = Util.mod_exists
local reverse = Util.reverse
local is_windows = Util.is_windows

---@class Project.Health
local Health = {}

---@return boolean setup_called
function Health.setup_check()
    start('Setup')

    local setup_called = vim.g.project_setup == 1

    if not setup_called then
        h_error('`setup()` has not been called!')
        return setup_called
    end

    ok('`setup()` has been called!')

    if vim.fn.has('nvim-0.11') == 1 then
        ok('nvim version is at least `v0.11`')
    else
        h_warn('nvim version is lower than `v0.11`!')
    end

    if is_windows() then
        h_warn([[
        `DISCLAIMER`

        You're running on Windows. Issues are more likely to occur,
        bear that in mind.

        Please report any issues to the maintainers.
        ]])
    end

    return setup_called
end

function Health.options_check()
    start('Config')

    local Options = Config.options

    if not is_type('table', Options) then
        h_error('The config table is missing!')
        return
    end

    table.sort(Options)
    local exceptions = {
        'new',
        'verify_datapath',
        'verify_histsize',
        'verify_methods',
        'verify_scope_chdir',
    }

    for k, v in next, Options do
        if not in_tbl(exceptions, k) then
            ---@type table|string[]|nil
            local constraints = nil

            if k == 'scope_chdir' then
                constraints = { 'global', 'tab', 'win' }
            end

            local str, warning = format_per_type(type(v), v, nil, constraints)

            str = fmt(' - %s: %s', k, str)

            if is_type('boolean', warning) and warning then
                h_warn(str)
            else
                ok(str)
            end
        end
    end
end

function Health.history_check()
    start('History')

    ---@type HistoryCheck[]
    local P = {
        {
            name = 'datapath',
            type = 'directory',
            path = Path.datapath,
        },
        {
            name = 'projectpath',
            type = 'directory',
            path = Path.projectpath,
        },
        {
            name = 'historyfile',
            type = 'file',
            path = Path.historyfile,
        },
    }

    for _, v in next, P do
        local fname, ftype, path = v.name, v.type, v.path

        local stat = uv.fs_stat(path)

        if stat == nil then
            h_error(fmt('%s: `%s` is missing or not readable!', fname, path))
        elseif stat.type ~= ftype then
            h_error(fmt('%s: `%s` is not of type `%s`!', fname, path, ftype))
        else
            ok(fmt('%s: `%s`', fname, path))
        end
    end
end

function Health.project_check()
    start('Current Project')

    local curr, method, last = Api.current_project, Api.current_method, Api.last_project
    local msg = fmt('Current project: `%s`\n', curr ~= nil and curr or 'No Current Project')
    msg = fmt('%sMethod used: `%s`\n', msg, (method ~= nil and method or 'No method available'))
    msg = fmt('%sLast project: `%s`\n', msg, (last ~= nil and last or 'No Last Project In History'))
    info(msg)

    start('Active Sessions')

    local active = History.has_watch_setup
    local projects = History.session_projects

    if not active or empty(projects) then
        h_warn('No active session projects!')
        return
    end

    projects = dedup(copy(projects))

    ---@cast projects string[]
    for k, v in ipairs(projects) do
        info(fmt('[`%s`]: `%s`', tostring(k), v))
    end
end

function Health.telescope_check()
    start('Telescope')
    local Opts = Config.options

    if not mod_exists('telescope') then
        h_warn(
            fmt(
                '`telescope.nvim` is not installed.\n%s',
                "This doesn't represent an issue necessarily"
            )
        )
        return
    end

    if not require('telescope').extensions.projects then
        h_warn('`projects` Telescope picker is missing!\nHave you loaded it?')
        return
    end

    ok('`projects` picker extension loaded')

    if not is_type('table', Opts.telescope) then
        h_warn('`projects` does not have telescope options set up')
        return
    end

    local sort = Opts.telescope.sort

    if not in_list({ 'newest', 'oldest' }, sort) then
        h_warn('Telescope `sort` option not configured correctly!')
        return
    end

    ok(fmt("Sorting order: `'%s'`", sort))
end

function Health.fzf_lua_check()
    start('Fzf-Lua')
    local Opts = Config.options

    if not mod_exists('telescope') then
        h_warn(
            fmt('`fzf-lua` is not installed. \n%s', "This doesn't represent an issue necessarily")
        )
        return
    end

    ok('`fzf-lua` is installed!')

    if not (vim.cmd.ProjectFzf and vim.is_callable(vim.cmd.ProjectFzf)) then
        h_warn('`:ProjectFzf` user command is not loaded!')
        return
    end

    ok('`:ProjectFzf` user command loaded!')
end

function Health.recent_proj_check()
    start('Recent Projects')
    local recents = Api.get_recent_projects()

    if empty(recents) then
        h_warn([[
            `No projects found in history!`

            If this is your first time using this plugin,
            or you just set a different `historypath` for your plugin,
            then you can ignore this.


            If this keeps appearing, though, check your config
            and submit an issue if pertinent.
                ]])
        return
    end

    recents = reverse(copy(recents))

    for i, project in next, recents do
        info(fmt('`%s`. `%s`', i, project))
    end
end

---This is called when running `:checkhealth project`.
--- ---
function Health.check()
    if not Health.setup_check() then
        return
    end

    --- NOTE: Order matters below!

    Health.telescope_check()
    Health.fzf_lua_check()
    Health.project_check()
    Health.history_check()
    Health.options_check()
    Health.recent_proj_check()
end

return Health

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
