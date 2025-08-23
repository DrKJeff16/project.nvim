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

local ERROR = vim.log.levels.ERROR

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

    if t == nil or not (type(t) == 'string' and in_tbl(TYPES, t)) then
        return false
    end

    return data ~= nil and type(data) == t
end

---Checks if module `mod` exists to be imported.
--- ---
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
    if not Util.is_type('table', T) then
        error('(project.utils.util.dedup): Data is not a table!', ERROR)
    end

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
---@return table
function Util.reverse(T)
    if not Util.is_type('table', T) then
        error('project.utils.util.reverse: Arg is not a table', ERROR)
    end

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
    if not Util.is_type('string', dir) then
        error('(project.utils.util.dir_exists): Argument is not a string', ERROR)
    end

    local stat = uv.fs_stat(dir)

    return stat ~= nil and stat.type == 'directory'
end

---@param path_to_normalise string
---@return string normalised_path
function Util.normalise_path(path_to_normalise)
    local normalised_path = path_to_normalise:gsub('\\', '/'):gsub('//', '/')

    if Util.is_windows() then
        normalised_path = normalised_path:sub(1, 1):lower() .. normalised_path:sub(2)
    end

    return normalised_path
end

return Util
