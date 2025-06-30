---@diagnostic disable:missing-fields
---@diagnostic disable:need-check-nil

local health = vim.health
local uv = vim.uv or vim.loop
local ERROR = vim.log.levels.ERROR

local empty = vim.tbl_isempty

---@param t 'nil'|'number'|'string'|'boolean'|'table'|'function'|'thread'|'userdata'
---@param data any
---@return boolean
local function is_type(t, data)
    local types = {
        'nil',
        'number',
        'string',
        'boolean',
        'table',
        'function',
        'thread',
        'userdata',
    }

    if t == nil or type(t) ~= 'string' or not vim.tbl_contains(types, t) then
        return false
    end

    -- `nil` is a special case
    if t == 'nil' then
        return data == nil
    end

    return (data ~= nil and type(data) == t)
end

---@param T table|string[]
---@return table|string[]
local function dedup(T)
    if not is_type('table', T) then
        error('(project_nvim.health.dedup): Attempting to dedup data that is not a table!', ERROR)
    end

    if empty(T) then
        return T
    end

    local t = {}

    for _, v in next, T do
        if not vim.tbl_contains(t, v) then
            table.insert(t, v)
        end
    end

    return t
end

---@param t 'number'|'string'|'boolean'|'table'
---@param data number|string|boolean|table
---@param sep? string
---@param constraints? string[]
---@return string
---@return true?
local function format_per_type(t, data, sep, constraints)
    sep = is_type('string', sep) and sep or ''
    constraints = is_type('table', constraints) and constraints or nil

    if t == 'string' then
        local res = string.format('%s`"%s"`', sep, data)
        if not is_type('table', constraints) then
            return res
        end

        if is_type('table', constraints) and vim.tbl_contains(constraints, data) then
            return res
        end

        return res, true
    end

    if t == 'number' or t == 'boolean' then
        return string.format('%s`%s`', sep, tostring(data))
    end

    local msg = ''

    if t == 'nil' then
        return sep .. msg .. ' `nil`'
    end

    if t ~= 'table' then
        return sep .. msg .. ' `?`'
    end

    if vim.tbl_isempty(data) then
        return sep .. msg .. ' `{}`'
    end

    sep = sep .. '  '

    for k, v in next, data do
        if is_type('number', k) then
            k = tostring(k)
        end

        msg = msg .. string.format('%s\n[%s]: `', sep, k)

        if not is_type('string', v) then
            msg = msg .. string.format('%s', format_per_type(type(v), v, sep))
        else
            msg = msg .. string.format('"%s"`', v)
        end
    end

    return msg
end

local Health = {}

function Health.options_check()
    health.start('Config')

    local Options = require('project_nvim.config').options

    if not is_type('table', Options) then
        health.error('The config table is missing!')
        return
    end

    -- ignore_lsp: table|string[]
    -- datapath: string
    -- exclude_dirs: table|string[]
    -- scope_chdir: 'global'|'tab'|'win'
    -- patterns: string[]
    -- show_hidden: boolean
    -- manual_mode: boolean
    -- silent_chdir: boolean
    -- detection_methods: string[]

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

        if is_type('boolean', warn) and warn then
            health.warn(' - ' .. k .. ': ' .. str)
        else
            health.ok(' - ' .. k .. ': ' .. str)
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

    local setup_called = require('project_nvim.config').setup_called == nil and false or true

    if setup_called then
        health.ok("`require('project_nvim').setup()` has been called")
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

function Health.check()
    if Health.setup_check() then
        Health.project_check()
        Health.history_check()
        Health.options_check()
    end
end

return Health
