---@diagnostic disable:missing-fields

local uv = vim.uv or vim.loop

local start = vim.health.start or vim.health.report_start
local ok = vim.health.ok or vim.health.report_ok
local info = vim.health.info or vim.health.report_info
local warn = vim.health.warn or vim.health.report_warn
local h_error = vim.health.error or vim.health.report_error

local empty = vim.tbl_isempty

local Util = require('project_nvim.utils.util')

local is_type = Util.is_type
local dedup = Util.dedup
local format_per_type = Util.format_per_type
local mod_exists = Util.mod_exists

---@class Project.Health
-- This is called when running `:checkhealth project_nvim`
-- ---
---@field check fun()
---@field setup_check fun(): boolean
---@field options_check fun()
---@field history_check fun()
---@field project_check fun()
---@field telescope_check fun()
---@field recent_proj_check fun()
local Health = {}

function Health.options_check()
    start('Config')

    local Options = require('project_nvim.config').options

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

        str = string.format(' - %s: %s', k, str)

        if is_type('boolean', warn) and warning then
            warn(str)
        else
            ok(str)
        end
    end
end

function Health.history_check()
    start('History')

    local Path = require('project_nvim.utils.path')

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
            h_error(string.format('%s: `%s` is missing or not readable!', fname, value))
            goto continue
        end

        if stat.type ~= ftype then
            h_error(string.format('%s: `%s` is not of type `%s`!', fname, value, ftype))
            goto continue
        end

        ok(string.format('%s: `%s`', fname, value))

        ::continue::
    end
end

---@return boolean
function Health.setup_check()
    start('Setup')

    local setup_called = require('project_nvim.config').setup_called or false

    if setup_called then
        ok("`require('project_nvim').setup()` has been called")

        if Util.is_windows() then
            warn(
                string.format(
                    '%s\n\n\t%s',
                    'Running on Windows. Issues might occur.',
                    'Please report any issues to the maintainers'
                )
            )
        end

        if vim.fn.has('nvim-0.11') == 1 then
            ok('nvim version is at least `v0.11`')
        else
            warn('nvim version is lower than `v0.11`!')
        end
    else
        h_error("`require('project_nvim').setup()` has not been called!")
    end

    return setup_called
end

function Health.project_check()
    start('Current Project')

    local curr, method, last = require('project_nvim').current_project()
    local msg = ''

    if curr == nil then
        msg = 'Current project: **No current project**'
    else
        msg = string.format('Current project: `%s`', curr)
    end

    info(msg)

    if method == nil then
        msg = 'Method used: **No method available**'
    else
        msg = string.format('Method used: `%s`', method)
    end

    info(msg)

    if last == nil then
        msg = 'Last project: **No method available**\n'
    else
        msg = string.format('Last project: `%s`\n', last)
    end

    info(msg)

    start('Active Sessions')

    local History = require('project_nvim.utils.history')
    local active = History.has_watch_setup
    local projects = History.session_projects

    if active and not empty(projects) then
        projects = dedup(vim.deepcopy(projects))

        for k, v in next, projects do
            info(string.format('`[%s]`: `%s`', tostring(k), v))
        end
    else
        warn('No active session projects!')
    end
end

function Health.telescope_check()
    if not mod_exists('telescope') then
        return
    end

    start('Telescope')

    if not mod_exists('telescope._extensions.projects') then
        warn('Extension is missing', 'Have you set it up?')
        return
    end

    ok('Extension loaded')

    local Opts = require('project_nvim.config').options

    if not is_type('table', Opts.telescope) then
        warn('`project_nvim` does not have telescope options set up')
        return
    end

    if not vim.tbl_contains({ 'newest', 'oldest' }, Opts.telescope.sort) then
        warn('Telescope setup option not configured correctly!')
    end

    ok(string.format("Sorting order: `'%s'`", Opts.telescope.sort))
end

function Health.recent_proj_check()
    start('Recent Projects')

    local recents = require('project_nvim.api').get_recent_projects()

    if vim.tbl_isempty(recents) then
        warn(
            '**No projects found in history!**\n'
                .. '_If this is your first time using this plugin,_\n'
                .. '_or you just set a different `historypath` for your plugin,_\n'
                .. '_then you can ignore this._\n\n'
                .. 'If this keeps appearing though, check your config and if needed create an issue.'
        )
        return
    end

    recents = Util.reverse(vim.deepcopy(recents))

    for i, project in next, recents do
        info(string.format('%s. `%s`', tostring(i), project))
    end
end

-- This is called when running `:checkhealth project_nvim`
-- ---
function Health.check()
    if not Health.setup_check() then
        return
    end

    Health.history_check()
    Health.project_check()
    Health.telescope_check()
    Health.options_check()
    Health.recent_proj_check()
end

return Health
