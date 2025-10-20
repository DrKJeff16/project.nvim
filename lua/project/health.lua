local MODSTR = 'project.health'
local uv = vim.uv or vim.loop
local start = vim.health.start or vim.health.report_start
local h_ok = vim.health.ok or vim.health.report_ok
local h_info = vim.health.info or vim.health.report_info
local h_warn = vim.health.warn or vim.health.report_warn
local h_error = vim.health.error or vim.health.report_error
local empty = vim.tbl_isempty
local copy = vim.deepcopy
local in_list = vim.list_contains

local Util = require('project.utils.util')
local Path = require('project.utils.path')
local History = require('project.utils.history')
local Config = require('project.config')
local Api = require('project.api')
local Log = require('project.utils.log')
local is_type = Util.is_type
local dedup = Util.dedup
local format_per_type = Util.format_per_type
local mod_exists = Util.mod_exists
local reverse = Util.reverse
local is_windows = Util.is_windows
local vim_has = Util.vim_has

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

    h_ok('`setup()` has been called!')
    if vim_has('nvim-0.11') then
        h_ok('nvim version is at least `v0.11`')
    else
        h_warn('nvim version is lower than `v0.11`!')
    end

    if vim.fn.executable('fd') == 1 then
        h_ok('`fd` executable in `PATH`')
    elseif vim.fn.executable('fdfind') == 1 then
        h_ok('`fdfind` executable in `PATH`')
    else
        h_warn('`fd` nor `fdfind` were found! Some utilities from this plugin may not work.')
    end

    if is_windows() and vim.g.project_disable_win32_warning ~= 1 then
        h_warn([[
`DISCLAIMER`

You're running on Windows. Issues are more likely to occur,
bear that in mind.

Please report any issues to the maintainers.

If you wish to disable this warning, set `g:project_disable_win32_warning` to `1`.
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
        'telescope',
        'verify_datapath',
        'verify_histsize',
        'verify_logging',
        'verify_methods',
        'verify_scope_chdir',
    }
    for k, v in pairs(Options) do
        if not in_list(exceptions, k) then
            ---@type table|string[]|nil
            local constraints = nil
            if k == 'scope_chdir' then
                constraints = { 'global', 'tab', 'win' }
            end

            local str, warning = format_per_type(type(v), v, nil, constraints)
            str = (' - %s: %s'):format(k, str)
            if is_type('boolean', warning) and warning then
                h_warn(str)
            else
                h_ok(str)
            end
        end
    end
end

function Health.history_check()
    start('History')
    local P = { ---@type { name: string, type: ('file'|'directory'), path: string }[]
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
    for _, v in ipairs(P) do
        local stat = uv.fs_stat(v.path)
        if not stat then
            h_error(('%s: `%s` is missing or not readable!'):format(v.name, v.path))
            return
        end
        if stat.type ~= v.type then
            h_error(('%s: `%s` is not of type `%s`!'):format(v.name, v.path, v.type))
            return
        end
        h_ok(('%s: `%s`'):format(v.name, v.path))
    end
end

function Health.project_check()
    start('Current Project')
    local curr, method, last = Api.current_project, Api.current_method, Api.last_project
    local msg = ('Current project: `%s`\n'):format(curr ~= nil and curr or 'No Current Project')
    msg = ('%sMethod used: `%s`\n'):format(msg, (method ~= nil and method or 'No method available'))
    msg = ('%sLast project: `%s`'):format(
        msg,
        (last ~= nil and last or 'No Last Project In History')
    )
    h_info(msg)

    start('Active Sessions')
    local active = History.has_watch_setup
    local projects = copy(History.session_projects)
    if not active or empty(projects) then
        h_warn('No active session projects!')
        return
    end

    for k, v in ipairs(dedup(projects)) do
        h_info(('[`%s`]: `%s`'):format(k, v))
    end
end

function Health.telescope_check()
    start('Telescope')
    if not mod_exists('telescope') then
        h_warn([[
`telescope.nvim` is not installed.

This doesn't represent an issue necessarily
        ]])
        return
    end
    if not require('telescope').extensions.projects then
        h_warn('`projects` Telescope picker is missing!\nHave you loaded it?')
        return
    end
    h_ok('`projects` picker extension loaded')

    if not is_type('table', Config.options.telescope) then
        h_warn('`projects` does not have telescope options set up')
        return
    end

    start('Telescope Config')
    for k, v in pairs(Config.options.telescope) do
        local str, warning = format_per_type(type(v), v)
        str = ('`%s`: %s'):format(k, str)
        if is_type('boolean', warning) and warning then
            h_warn(str)
        else
            h_ok(str)
        end
    end
end

function Health.fzf_lua_check()
    start('Fzf-Lua')
    if not Config.options.fzf_lua.enabled then
        h_warn([[
`fzf-lua` integration is disabled.

This doesn't represent an issue necessarily
        ]])
        return
    end

    h_ok('`fzf-lua` integration enabled!')
    if not (vim.cmd.ProjectFzf and vim.is_callable(vim.cmd.ProjectFzf)) then
        h_warn('`:ProjectFzf` user command is not loaded!')
    else
        h_ok('`:ProjectFzf` user command loaded!')
    end
end

function Health.recent_proj_check()
    start('Recent Projects')
    local recents = History.get_recent_projects()
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
    for i, project in ipairs(reverse(recents)) do
        h_info(('`%s`. `%s`'):format(i, project))
    end
end

---This is called when running `:checkhealth project`.
--- ---
function Health.check()
    if not Health.setup_check() then
        return
    end
    Health.project_check()
    Health.history_check()
    Health.telescope_check()
    Health.fzf_lua_check()
    Health.options_check()
    Health.recent_proj_check()

    Log.debug(('(%s): `checkhealth` successfully called.'):format(MODSTR))
end

return Health
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
