---@diagnostic disable:missing-fields
---@diagnostic disable:need-check-nil

local health = vim.health
local uv = vim.uv or vim.loop

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

---@param t 'number'|'string'|'boolean'|'table'
---@param data number|string|boolean|table
---@param sep? string
---@return string
local function format_per_type(t, data, sep)
    sep = is_type('string', sep) and sep or ''

    if t == 'string' then
        return string.format('%s`"%s"`', sep, data)
    end

    if t == 'number' or t == 'boolean' then
        return string.format('%s`%s`', sep, tostring(data))
    end

    local msg = ''

    if t ~= 'table' then
        return sep .. msg .. ' `?`'
    end

    if vim.tbl_isempty(data) then
        return sep .. msg .. '`{}`'
    end

    msg = ''

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
        health.info(k .. ': ' .. format_per_type(type(v), v))
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

function Health.check()
    Health.history_check()
    Health.options_check()
end

return Health
