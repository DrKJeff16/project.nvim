local uv = vim.uv or vim.loop
local fmt = string.format

local start = vim.health.start or vim.health.report_start
local ok = vim.health.ok or vim.health.report_ok
local info = vim.health.info or vim.health.report_info
local h_warn = vim.health.warn or vim.health.report_warn
local h_error = vim.health.error or vim.health.report_error

local empty = vim.tbl_isempty

local Util = require('project.utils.util')

local is_type = Util.is_type
local dedup = Util.dedup
local format_per_type = Util.format_per_type
local mod_exists = Util.mod_exists

---@class Project.Health
local Health = {}

function Health.options_check()
    start('Config')

    local Options = require('project.config').options
    table.sort(Options)

    if not is_type('table', Options) then
        h_error('The config table is missing!')
        return
    end

    for k, v in next, Options do
        k = is_type('string', k) and k or ''

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

function Health.history_check()
    start('History')

    local Path = require('project.utils.path')

    ---@class HistoryChecks
    ---@field name 'datapath'|'projectpath'|'historyfile'
    ---@field type 'file'|'directory'
    ---@field value string

    ---@type HistoryChecks[]
    local P = {
        {
            name = 'datapath',
            type = 'directory',
            value = Path.datapath,
        },
        {
            name = 'projectpath',
            type = 'directory',
            value = Path.projectpath,
        },
        {
            name = 'historyfile',
            type = 'file',
            value = Path.historyfile,
        },
    }

    for _, v in next, P do
        local fname, ftype, value = v.name, v.type, v.value

        local stat = uv.fs_stat(value)

        if stat == nil then
            h_error(fmt('%s: `%s` is missing or not readable!', fname, value))
            goto continue
        end

        if stat.type ~= ftype then
            h_error(fmt('%s: `%s` is not of type `%s`!', fname, value, ftype))
            goto continue
        end

        ok(fmt('%s: `%s`', fname, value))

        ::continue::
    end
end

---@return boolean
function Health.setup_check()
    start('Setup')

    local setup_called = require('project.config').setup_called or false

    if setup_called then
        ok("`require('project').setup()` has been called")

        if Util.is_windows() then
            h_warn(
                fmt(
                    '%s\n\n\t%s',
                    'Running on Windows. Issues might occur.',
                    'Please report any issues to the maintainers'
                )
            )
        end

        if vim.fn.has('nvim-0.11') == 1 then
            ok('nvim version is at least `v0.11`')
        else
            h_warn('nvim version is lower than `v0.11`!')
        end
    else
        h_error("`require('project').setup()` has not been called!")
    end

    return setup_called
end

function Health.project_check()
    start('Current Project')

    local Api = require('project.api')

    local curr, method, last = Api.current_project, Api.current_method, Api.last_project
    local msg = ''

    if curr == nil then
        msg = 'Current project: **No current project**'
    else
        msg = fmt('Current project: `%s`', curr)
    end

    info(msg)

    if method == nil then
        msg = 'Method used: **No method available**'
    else
        msg = fmt('Method used: `%s`', method)
    end

    info(msg)

    if last == nil then
        msg = 'Last project: **No method available**'
    else
        msg = fmt('Last project: `%s`', last)
    end

    info(msg)

    start('Active Sessions')

    local History = require('project.utils.history')
    local active = History.has_watch_setup
    local projects = History.session_projects

    if active and not empty(projects) then
        projects = dedup(vim.deepcopy(projects))

        for k, v in next, projects do
            info(fmt('`[%s]`: `%s`', tostring(k), v))
        end
    else
        h_warn('No active session projects!')
    end
end

function Health.telescope_check()
    start('Telescope')

    if not mod_exists('telescope') then
        h_warn('Telescope is not installed')
        return
    end

    if not mod_exists('telescope._extensions.projects') then
        h_warn('`projects` Telescope picker is missing!\nHave you set it up?')
        return
    end

    ok('`projects` picker extension loaded')

    local Opts = require('project.config').options

    if not is_type('table', Opts.telescope) then
        h_warn('`project` does not have telescope options set up')
        return
    end

    if not vim.tbl_contains({ 'newest', 'oldest' }, Opts.telescope.sort) then
        h_warn('Telescope setup option not configured correctly!')
    end

    ok(fmt("Sorting order: `'%s'`", Opts.telescope.sort))
end

function Health.recent_proj_check()
    start('Recent Projects')

    local recents = require('project.api').get_recent_projects()

    if vim.tbl_isempty(recents) then
        h_warn([[
            **No projects found in history!**\n
            _If this is your first time using this plugin,_\n
            _or you just set a different `historypath` for your plugin,_\n
            _then you can ignore this._\n\n
            If this keeps appearing though, check your config and if needed create an issue.
                ]])
        return
    end

    recents = Util.reverse(vim.deepcopy(recents))

    for i, project in next, recents do
        info(fmt('%s. `%s`', tostring(i), project))
    end
end

-- This is called when running `:checkhealth project`
-- ---
function Health.check()
    if not Health.setup_check() then
        return
    end

    -- NOTE: Order matters below!

    Health.telescope_check()
    Health.project_check()
    Health.history_check()
    Health.options_check()
    Health.recent_proj_check()
end

return Health
