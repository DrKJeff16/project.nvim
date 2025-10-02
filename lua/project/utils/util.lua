---@alias Project.Utils.Util.Types 'number'|'string'|'boolean'|'table'|'function'|'thread'|'userdata'

local uv = vim.uv or vim.loop
local empty = vim.tbl_isempty
local in_tbl = vim.tbl_contains

---@class Project.Utils.Util
local Util = {}

function Util.vim_has(feature)
    return vim.fn.has(feature) == 1
end

---Checks whether nvim is running on Windows.
--- ---
---@return boolean
function Util.is_windows()
    return vim.fn.has('win32') == 1
end

---@param str string
---@param use_dot? boolean
---@param triggers? string[]
---@return string new_str
function Util.capitalize(str, use_dot, triggers)
    if Util.vim_has('nvim-0.11') then
        vim.validate('str', str, 'string', false)
        vim.validate('use_dot', use_dot, 'boolean', true)
        vim.validate('triggers', triggers, 'table', true, 'string[]')
    else
        vim.validate({
            str = { str, 'string' },
            use_dot = { use_dot, { 'boolean', 'nil' } },
            triggers = { triggers, { 'table', 'nil' } },
        })
    end
    use_dot = use_dot ~= nil and use_dot or false
    triggers = triggers or { ' ', '' }
    if str == '' then
        return str
    end
    if not in_tbl(triggers, ' ') then
        table.insert(triggers, ' ')
    end
    if not in_tbl(triggers, '') then
        table.insert(triggers, '')
    end

    local strlen = str:len()
    local prev_char, new_str, i = '', '', 1
    local dot = true
    while i <= strlen do
        local char = str:sub(i, i)
        if char == char:lower() and in_tbl(triggers, prev_char) then
            char = dot and char:upper() or char:lower()
            if dot then
                dot = false
            end
        else
            char = char:lower()
        end
        dot = (use_dot and not dot) and (char == '.') or (use_dot and dot or true)
        new_str = ('%s%s'):format(new_str, char)
        prev_char = char
        i = i + 1
    end
    return new_str
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
    if Util.vim_has('nvim-0.11') then
        vim.validate('data', data, TYPES, true, 'any')
        vim.validate('t', t, function(v)
            if v == nil or type(v) ~= 'string' then
                return false
            end
            return in_tbl(TYPES, v)
        end, false, "'number'|'string'|'boolean'|'table'|'function'|'thread'|'userdata'")
    else
        vim.validate({
            data = { data, TYPES },
            t = {
                t,
                function(v)
                    if v == nil or type(v) ~= 'string' then
                        return false
                    end
                    return in_tbl(TYPES, v)
                end,
            },
        })
    end
    return data ~= nil and type(data) == t
end

---Checks if module `mod` exists to be imported.
--- ---
---@param mod string The `require()` argument to be checked
---@return boolean exists A boolean indicating whether the module exists or not
function Util.mod_exists(mod)
    if Util.vim_has('nvim-0.11') then
        vim.validate('mod', mod, 'string', false)
    else
        vim.validate({ mod = { mod, 'string' } })
    end
    if mod == '' then
        return false
    end
    local exists = pcall(require, mod)
    return exists
end

---Left strip a given leading `char` in a string, if any.
--- ---
---@param char string
---@param str string
---@return string new_str
function Util.lstrip(char, str)
    if Util.vim_has('nvim-0.11') then
        vim.validate('char', char, 'string', false)
        vim.validate('str', str, 'string', false)
    else
        vim.validate({
            char = { char, 'string' },
            str = { str, 'string' },
        })
    end
    if str == '' or not vim.startswith(str, char) then
        return str
    end

    local i, len, new_str = 1, str:len(), ''
    local other = false
    while i <= len + 1 do
        if str:sub(i, i) ~= char and not other then
            other = true
        end
        if other then
            new_str = ('%s%s'):format(new_str, str:sub(i, i))
        end
        i = i + 1
    end
    return new_str
end

---Right strip a given leading `char` in a string, if any.
--- ---
---@param char string
---@param str string
---@return string new_str
function Util.rstrip(char, str)
    if Util.vim_has('nvim-0.11') then
        vim.validate('char', char, 'string', false)
        vim.validate('str', str, 'string', false)
    else
        vim.validate({
            char = { char, 'string' },
            str = { str, 'string' },
        })
    end
    if str == '' then
        return str
    end

    str = str:reverse()
    if not vim.startswith(str, char) then
        return str:reverse()
    end
    return Util.lstrip(char, str):reverse()
end

---Strip a given leading `char` in a string, if any, bidirectionally.
--- ---
---@param char string
---@param str string
---@return string new_str
function Util.strip(char, str)
    if Util.vim_has('nvim-0.11') then
        vim.validate('char', char, 'string', false)
        vim.validate('str', str, 'string', false)
    else
        vim.validate({
            char = { char, 'string' },
            str = { str, 'string' },
        })
    end
    if str == '' then
        return str
    end
    return Util.rstrip(char, Util.lstrip(char, str))
end

---Get rid of all duplicates in input table.
---
---If table is empty, it'll just return it as-is.
---
---If the data passed to the function is not a table,
---an error will be raised.
--- ---
---@param T table
---@return table NT
function Util.dedup(T)
    if Util.vim_has('nvim-0.11') then
        vim.validate('T', T, 'table', false)
    else
        vim.validate({ T = { T, 'table' } })
    end
    if empty(T) then
        return T
    end

    local NT = {}
    for _, v in next, T do
        local not_dup = false
        if Util.is_type('table', v) then
            not_dup = not in_tbl(NT, function(val)
                return vim.deep_equal(val, v)
            end, { predicate = true })
        else
            not_dup = not in_tbl(NT, v)
        end
        if not_dup then
            table.insert(NT, v)
        end
    end
    return NT
end

---@param t 'number'|'string'|'boolean'|'table'|'function'
---@param data nil|number|string|boolean|table|fun()
---@param sep? string
---@param constraints? string[]
---@return string
---@return boolean|nil
function Util.format_per_type(t, data, sep, constraints)
    if Util.vim_has('nvim-0.11') then
        vim.validate('t', t, function(v)
            if v == nil or type(v) ~= 'string' then
                return false
            end

            return in_tbl({ 'number', 'string', 'boolean', 'table', 'function' }, v)
        end, false, "'number'|'string'|'boolean'|'table'|'function'")
        vim.validate(
            'data',
            data,
            { 'number', 'string', 'boolean', 'table', 'function' },
            true,
            'nil|number|string|boolean|table|fun()'
        )
        vim.validate('sep', sep, 'string', true)
        vim.validate('constraints', constraints, 'table', true, 'string[]')
    else
        vim.validate({
            t = {
                t,
                function(v)
                    if v == nil or type(v) ~= 'string' then
                        return false
                    end

                    return in_tbl({ 'number', 'string', 'boolean', 'table', 'function' }, v)
                end,
            },
            data = {
                data,
                { 'number', 'string', 'boolean', 'table', 'function', 'nil' },
            },
            sep = { sep, { 'string', 'nil' } },
            constraints = { constraints, { 'table', 'nil' } },
        })
    end

    local is_type = Util.is_type
    sep = sep or ''
    constraints = constraints or nil
    if t == 'string' then
        local res = ('%s`"%s"`'):format(sep, data)
        if not is_type('table', constraints) then
            return res
        end
        if constraints ~= nil and in_tbl(constraints, data) then
            return res
        end
        return res, true
    end
    if t == 'number' or t == 'boolean' then
        return ('%s`%s`'):format(sep, tostring(data))
    end
    if t == 'function' then
        return ('%s`%s`'):format(sep, t)
    end

    local msg = ''
    if t == 'nil' then
        return ('%s%s `nil`'):format(sep, msg)
    end
    if t ~= 'table' then
        return ('%s%s `?`'):format(sep, msg)
    end
    if empty(data) then
        return ('%s%s `{}`'):format(sep, msg)
    end

    sep = ('%s '):format(sep)
    for k, v in next, data do
        k = is_type('number', k) and ('[%s]'):format(tostring(k)) or k
        msg = ('%s\n%s%s: '):format(msg, sep, k)
        if not is_type('string', v) then
            msg = ('%s%s'):format(msg, Util.format_per_type(type(v), v, sep))
        else
            msg = ('%s`"%s"`'):format(msg, v)
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
    if Util.vim_has('nvim-0.11') then
        vim.validate('T', T, 'table', false)
    else
        vim.validate({ T = { T, 'table' } })
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
    if Util.vim_has('nvim-0.11') then
        vim.validate('dir', dir, 'string', false)
    else
        vim.validate({ dir = { dir, 'string' } })
    end

    local stat = uv.fs_stat(dir)
    return stat ~= nil and stat.type == 'directory'
end

---@param path string
---@return boolean
function Util.path_exists(path)
    if Util.vim_has('nvim-0.11') then
        vim.validate('path', path, 'string', false)
    else
        vim.validate({ path = { path, 'string' } })
    end
    if Util.dir_exists(path) then
        return true
    end

    --- CREDITS: @tomaskallup
    return vim.fn.empty(vim.fn.glob(path:gsub('%[', '\\['))) == 0
end

---@param T table<string|integer, any>
---@return integer len
function Util.get_dict_size(T)
    if Util.vim_has('nvim-0.11') then
        vim.validate('T', T, 'table', false)
    else
        vim.validate({ T = { T, 'table' } })
    end
    local len = 0
    if vim.tbl_isempty(T) then
        return len
    end

    for _, _ in pairs(T) do
        len = len + 1
    end
    return len
end

---@param path string
---@return string normalised_path
function Util.normalise_path(path)
    if Util.vim_has('nvim-0.11') then
        vim.validate('path', path, 'string', false)
    else
        vim.validate({ path = { path, 'string' } })
    end
    local normalised_path = path:gsub('\\', '/'):gsub('//', '/')
    if Util.is_windows() then
        normalised_path = normalised_path:sub(1, 1):lower() .. normalised_path:sub(2)
    end
    return normalised_path
end

return Util
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
