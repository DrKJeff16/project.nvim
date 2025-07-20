---@diagnostic disable:missing-fields
---@diagnostic disable:need-check-nil

local health = vim.health
local uv = vim.uv or vim.loop

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

---@type Project.Health
local Health = {}

function Health.options_check()
    health.start('Config')

    local Options = require('project_nvim.config').options

    if not is_type('table', Options) then
        health.error('The config table is missing!')
        return
    end

    for k, v in next, Options do
        k = is_type('string', k) and k or ''

        ---@type table|string[]|nil
        local constraints = nil

        if k == 'scope_chdir' then
            constraints = { 'global', 'tab', 'win' }
        end

        local str
        local warn

        str, warn = format_per_type(type(v), v, nil, constraints)

        str = string.format(' - %s: %s', k, str)

        if is_type('boolean', warn) and warn then
            health.warn(str)
        else
            health.ok(str)
        end
    end
end

function Health.history_check()
    health.start('History')

    local Path = require('project_nvim.utils.path')

    ---@class HistoryChecks
    ---@field name 'datapath'|'projectpath'|'historyfile'
    ---@field value string
    ---@field type 'file'|'directory'

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
        local stat = uv.fs_stat(v.value)

        if is_type('nil', stat) then
            health.error(string.format('%s: `%s` is missing or not readable!', v.name, v.value))
            goto continue
        end

        if stat.type ~= v.type then
            health.error(string.format('%s: `%s` is not of type `%s`!', v.name, v.value, v.type))
            goto continue
        end

        health.ok(string.format('%s: `%s`', v.name, v.value))

        ::continue::
    end
end

---@return boolean
function Health.setup_check()
    local setup_called = require('project_nvim.config').setup_called or false

    health.start('Setup')

    if setup_called then
        health.ok("`require('project_nvim').setup()` has been called")

        if Util.is_windows() then
            health.warn(
                string.format(
                    '%s\n\n\t%s',
                    'Running on Windows. Issues might occur.',
                    'Please report any issues to the maintainers'
                )
            )
        end

        if vim.fn.has('nvim-0.11') == 1 then
            health.ok('nvim version is at least `v0.11`')
        else
            health.warn('nvim version is lower than `v0.11`!')
        end
    else
        health.error("`require('project_nvim').setup()` has not been called!")
    end

    return setup_called
end

function Health.project_check()
    health.start('Current Project')

    local curr, method, last = require('project_nvim').current_project()
    local msg = ''

    if curr == nil then
        msg = 'Current project: **No current project**'
    else
        msg = string.format('Current project: `%s`', curr)
    end

    health.info(msg)

    if method == nil then
        msg = 'Method used: **No method available**'
    else
        msg = string.format('Method used: `%s`', method)
    end

    health.info(msg)

    if last == nil then
        msg = 'Last project: **No method available**\n'
    else
        msg = string.format('Last project: `%s`\n', last)
    end

    health.info(msg)

    health.start('Active Sessions')

    local History = require('project_nvim.utils.history')
    local active = History.has_watch_setup
    local projects = History.session_projects

    if active and not empty(projects) then
        projects = dedup(vim.deepcopy(projects))

        for k, v in next, projects do
            health.info(string.format('`[%s]`: `%s`', tostring(k), v))
        end
    else
        health.warn('No active session projects!')
    end
end

function Health.telescope_check()
    if not mod_exists('telescope') then
        return
    end

    health.start('Telescope')

    if not mod_exists('telescope._extensions.projects') then
        health.warn('Extension is missing', 'Have you set it up?')
        return
    end

    health.ok('Extension loaded')

    local Opts = require('project_nvim.config').options

    if not is_type('table', Opts.telescope) then
        health.warn('`project_nvim` does not have telescope options set up')
        return
    end

    if not vim.tbl_contains({ 'newest', 'oldest' }, Opts.telescope.sort) then
        health.warn('Telescope setup option not configured correctly!')
    end

    health.ok(string.format("Sorting order: `'%s'`", Opts.telescope.sort))
end

-- This is called when running `:checkhealth project_nvim`
-- ---
function Health.check()
    if Health.setup_check() then
        Health.project_check()
        Health.history_check()
        Health.telescope_check()
        Health.options_check()
    end
end

return Health
