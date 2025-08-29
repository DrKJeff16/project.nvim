---@alias Project.Utils.Util.Types
---|'number'
---|'string'
---|'boolean'
---|'table'
---|'function'
---|'thread'
---|'userdata'

local fmt = string.format
local uv = vim.uv or vim.loop

local validate = vim.validate
local empty = vim.tbl_isempty
local in_tbl = vim.tbl_contains

---@class Project.Utils.Util
local Util = {}

---Checks whether nvim is running on Windows.
--- ---
---@return boolean
function Util.is_windows()
    return vim.fn.has('win32') == 1
end

---Checks whether `data` is of type `t` or not.
---
---If `data` is `nil`, the function will always return `false`.
--- ---
---@param t Project.Utils.Util.Types Any return value the `type()` function would return
---@param data any The data to be type-checked
---@return boolean
function Util.is_type(t, data)
    local TYPES = {
        'number',
        'string',
        'boolean',
        'table',
        'function',
        'thread',
        'userdata',
    }

    validate('t', t, function(v)
        if v == nil or type(v) ~= 'string' then
            return false
        end

        return in_tbl(TYPES, v)
    end, false, "'number'|'string'|'boolean'|'table'|'function'|'thread'|'userdata'")

    validate('data', data, TYPES, true, 'any')

    return data ~= nil and type(data) == t
end

---Checks if module `mod` exists to be imported.
---
---Example:
---
---```lua
---if require('project.utils.util').mod_exists('foo') then
---  require('foo')
---end
---```
---
--- ---
---@param mod string The `require()` argument to be checked
---@return boolean ok A boolean indicating whether the module exists or not
function Util.mod_exists(mod)
    validate('mod', mod, 'string', false)

    local is_type = Util.is_type

    if not is_type('string', mod) or mod == '' then
        return false
    end

    local ok = pcall(require, mod)

    return ok
end

---Get rid of all duplicates in input table.
---
---If table is empty, it'll just return it as-is.
---
---If the data passed to the function is not a table,
---an error will be raised.
--- ---
---@param T table
---@return table t
function Util.dedup(T)
    validate('T', T, 'table', false)

    local t = {}

    if empty(T) then
        return t
    end

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
        local res = fmt('%s`"%s"`', sep, data)
        if not is_type('table', constraints) then
            return res
        end

        if is_type('table', constraints) and in_tbl(constraints, data) then
            return res
        end

        return res, true
    end

    if t == 'number' or t == 'boolean' then
        return fmt('%s`%s`', sep, tostring(data))
    end

    local msg = ''

    if t == 'nil' then
        return fmt('%s%s `nil`', sep, msg)
    end

    if t ~= 'table' then
        return fmt('%s%s `?`', sep, msg)
    end

    if vim.tbl_isempty(data) then
        return fmt('%s%s `{}`', sep, msg)
    end

    sep = fmt('%s ', sep)

    ---@cast data table
    for k, v in next, data do
        k = is_type('number', k) and fmt('[%s]', tostring(k)) or k
        msg = fmt('%s\n%s%s: ', msg, sep, k)

        if not is_type('string', v) then
            msg = fmt('%s%s', msg, Util.format_per_type(type(v), v, sep))
        else
            msg = fmt('%s`"%s"`', msg, v)
        end
    end

    return msg
end

---Reverses a given table.
---
---If the passed data is an empty table, it'll be returned as-is.
---
---If the data passed to the function is not a table,
---an error will be raised.
--- ---
---@param T table
---@return table T
function Util.reverse(T)
    validate('T', T, 'table', false)

    if empty(T) then
        return T
    end

    local len = #T

    for i = 1, math.floor(len / 2) do
        T[i], T[len - i + 1] = T[len - i + 1], T[i]
    end

    return T
end

---Checks whether a given path is a directory or not.
---
---If the data passed to the function is not a string,
---an error will be raised.
--- ---
---@param dir string
---@return boolean
function Util.dir_exists(dir)
    validate('dir', dir, 'string', false)

    local stat = uv.fs_stat(dir)

    return stat ~= nil and stat.type == 'directory'
end

---@param path string
---@return string normalised_path
function Util.normalise_path(path)
    validate('path', path, 'string', false)
    local normalised_path = path:gsub('\\', '/'):gsub('//', '/')

    if Util.is_windows() then
        normalised_path = normalised_path:sub(1, 1):lower() .. normalised_path:sub(2)
    end

    return normalised_path
end

---@param v any
---@return boolean
function Util.int_validator(v)
    if not v then
        return false
    end

    if type(v) ~= 'number' then
        return false
    end

    return (math.floor(v) == v or math.ceil(v) == v)
end

return Util

---vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
