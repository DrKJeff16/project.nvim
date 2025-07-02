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

    local P = {
        { 'datapath', Path.datapath, 'directory' },
        { 'projectpath', Path.projectpath, 'directory' },
        { 'historyfile', Path.historyfile, 'file' },
    }

    for _, v in next, P do
        local stat = uv.fs_stat(v[2])

        if is_type('nil', stat) then
            health.error(string.format('%s: `"%s"` is missing or not readable!', v[1], v[2]))
            goto continue
        end

        if stat.type ~= v[3] then
            health.error(string.format('%s: `"%s"` is not a %s!', v[1], v[2], v[3]))
            goto continue
        end

        health.ok(string.format('%s: `"%s"`', v[1], v[2]))

        ::continue::
    end
end

---@return boolean
function Health.setup_check()
    health.start('Setup')

    local setup_called = is_type('nil', require('project_nvim.config').setup_called) and false
        or true

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
    else
        health.error("`require('project_nvim').setup()` has not been called!")
    end

    return setup_called
end

function Health.project_check()
    health.start('Active Sessions')

    local History = require('project_nvim.utils.history')
    local active = History.has_watch_setup
    local projects = History.session_projects

    if active and not empty(projects) then
        projects = dedup(vim.deepcopy(projects))
        health.info('Session Projects:' .. format_per_type(type(projects), projects))
    else
        health.warn('No active session projects!')
    end
end

function Health.telescope_check()
    if not mod_exists('telescope') then
        return
    end

    health.start('Telescope')

    if mod_exists('telescope._extensions.projects') then
        health.ok('Extension loaded')
    else
        health.warn('Extension is missing', 'Have you set it up?')
    end
end

function Health.check()
    if Health.setup_check() then
        Health.project_check()
        Health.history_check()
        Health.options_check()
        Health.telescope_check()
    end
end

return Health
