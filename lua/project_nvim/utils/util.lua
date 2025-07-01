---@diagnostic disable:missing-fields

---@alias Project.Utils.Util.AllTypes
---|'nil'
---|'number'
---|'string'
---|'boolean'
---|'table'
---|'function'
---|'thread'
---|'userdata'

---@class Project.Utils.Util
---@field is_type fun(t: Project.Utils.Util.AllTypes, data: any): boolean
---@field dedup fun(T: table|string[]): table|string[]
---@field format_per_type fun(t: 'number'|'string'|'table'|'boolean', data: number|string|table|boolean, sep: string?, constraints: string[]?): string?,boolean?
---@field mod_exists fun(mod: string): boolean

local ERROR = vim.log.levels.ERROR
local empty = vim.tbl_isempty
local in_tbl = vim.tbl_contains

---@type Project.Utils.Util
local Util = {}

---@param t Project.Utils.Util.AllTypes
---@param data any
---@return boolean
function Util.is_type(t, data)
    local TYPES = {
        'nil',
        'number',
        'string',
        'boolean',
        'table',
        'function',
        'thread',
        'userdata',
    }

    if t == nil or type(t) ~= 'string' or not in_tbl(TYPES, t) then
        return false
    end

    -- `nil` is a special case
    if t == 'nil' then
        return data == nil
    end

    return (data ~= nil and type(data) == t)
end

---@param mod string
---@return boolean
function Util.mod_exists(mod)
    local is_type = Util.is_type

    if not is_type('string', mod) or mod == '' then
        return false
    end

    local ok, _ = pcall(require, mod)

    return ok
end

---@param T table|string[]
---@return table|string[]
function Util.dedup(T)
    if not Util.is_type('table', T) then
        error(
            '(project_nvim.utils.util.dedup): Attempting to dedup data that is not a table!',
            ERROR
        )
    end

    if empty(T) then
        return T
    end

    local t = {}

    for _, v in next, T do
        if not in_tbl(t, v) then
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
---@return boolean?
function Util.format_per_type(t, data, sep, constraints)
    local is_type = Util.is_type

    sep = is_type('string', sep) and sep or ''
    constraints = is_type('table', constraints) and constraints or nil

    if t == 'string' then
        local res = string.format('%s`"%s"`', sep, data)
        if not is_type('table', constraints) then
            return res
        end

        if is_type('table', constraints) and in_tbl(constraints, data) then
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
            msg = msg .. string.format('%s', Util.format_per_type(type(v), v, sep))
        else
            msg = msg .. string.format('"%s"`', v)
        end
    end

    return msg
end

return Util
