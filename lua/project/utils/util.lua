---Non-legacy validation spec (>=v0.11)
---@class ValidateSpec
---@field [1] any
---@field [2] vim.validate.Validator
---@field [3]? boolean
---@field [4]? string

---@alias Project.Utils.Util.Types 'number'|'string'|'boolean'|'table'|'function'|'thread'|'userdata'

local MODSTR = 'project.utils.util'
local ERROR = vim.log.levels.ERROR
local uv = vim.uv or vim.loop
local empty = vim.tbl_isempty
local in_tbl = vim.tbl_contains
local in_list = vim.list_contains

---@class Project.Utils.Util
local M = {}

---Checks whether nvim is running on Windows.
--- ---
---@return boolean win32
function M.is_windows()
  return M.vim_has('win32')
end

---@param feature string
---@return boolean has
function M.vim_has(feature)
  return vim.fn.has(feature) == 1
end

---Dynamic `vim.validate()` wrapper. Covers both legacy and newer implementations
---@param T table<string, vim.validate.Spec|ValidateSpec>
function M.validate(T)
  if not M.vim_has('nvim-0.11') then
    ---Filter table to fit legacy standard
    ---@cast T table<string, vim.validate.Spec>
    for name, spec in pairs(T) do
      while #spec > 3 do
        table.remove(spec, #spec)
      end

      T[name] = spec
    end

    vim.validate(T)
    return
  end

  ---Filter table to fit non-legacy standard
  ---@cast T table<string, ValidateSpec>
  for name, spec in pairs(T) do
    while #spec > 4 do
      table.remove(spec, #spec)
    end

    T[name] = spec
  end

  for name, spec in pairs(T) do
    table.insert(spec, 1, name)
    vim.validate(unpack(spec))
  end
end

---Checks whether a given path is a directory or not.
---
---If the data passed to the function is not a string,
---an error will be raised.
--- ---
---@param dir string
---@return boolean
function M.dir_exists(dir)
  M.validate({ dir = { dir, { 'string' } } })

  local stat = uv.fs_stat(dir)
  return stat ~= nil and stat.type == 'directory'
end

---@param str string
---@param use_dot? boolean
---@param triggers? string[]
---@return string new_str
function M.capitalize(str, use_dot, triggers)
  M.validate({
    str = { str, { 'string' } },
    use_dot = { use_dot, { 'boolean', 'nil' }, true },
    triggers = { triggers, { 'table', 'nil' }, true },
  })

  if str == '' then
    return str
  end

  use_dot = use_dot ~= nil and use_dot or false
  triggers = triggers or { ' ', '' }
  if not in_list(triggers, ' ') then
    table.insert(triggers, ' ')
  end
  if not in_list(triggers, '') then
    table.insert(triggers, '')
  end

  local strlen = str:len()
  local prev_char, new_str, i = '', '', 1
  local dot = true
  while i <= strlen do
    local char = str:sub(i, i)
    if char == char:lower() and in_list(triggers, prev_char) then
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
---@return boolean correct_type
function M.is_type(t, data)
  return data ~= nil and type(data) == t
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
function M.reverse(T)
  M.validate({ T = { T, { 'table' } } })

  if empty(T) then
    return T
  end

  local len = #T
  for i = 1, math.floor(len / 2) do
    T[i], T[len - i + 1] = T[len - i + 1], T[i]
  end
  return T
end

---@param T table<string|integer, any>
---@return integer len
function M.get_dict_size(T)
  M.validate({ T = { T, { 'table' } } })

  local len = 0
  if vim.tbl_isempty(T) then
    return len
  end

  for _, _ in pairs(T) do
    len = len + 1
  end
  return len
end

---Checks if module `mod` exists to be imported.
--- ---
---@param mod string The `require()` argument to be checked
---@return boolean exists A boolean indicating whether the module exists or not
function M.mod_exists(mod)
  M.validate({ mod = { mod, { 'string' } } })

  if mod == '' then
    return false
  end
  local exists = pcall(require, mod)
  return exists
end

---@param nums number[]|number
---@return boolean int
function M.is_int(nums)
  M.validate({ nums = { nums, { 'number', 'table' } } })

  ---@cast nums number
  if M.is_type('number', nums) then
    return nums == math.floor(nums) and nums == math.ceil(nums)
  end

  ---@cast nums number[]
  for _, num in ipairs(nums) do
    if not M.is_int(num) then
      return false
    end
  end
  return true
end

---Emulates the behaviour of Python's builtin `range()` function.
--- ---
---@param x integer
---@param y integer
---@param step integer
---@return integer[] range_list
---@overload fun(x: integer): range_list: integer[]
---@overload fun(x: integer, y: integer): range_list: integer[]
function M.range(x, y, step)
  M.validate({
    x = { x, { 'number' } },
    y = { y, { 'number', 'nil' }, true },
    step = { step, { 'number', 'nil' }, true },
  })

  if not M.is_int(x) then
    error(('(%s.range): Argument `x` is not an integer: `%s`'):format(MODSTR, x), ERROR)
  end

  local range_list = {} ---@type integer[]
  if not (y or step) then
    y = x
    x = 1
    step = x <= y and 1 or -1

    table.insert(range_list, x)
    for v = x + step, y, step do
      table.insert(range_list, v)
    end
  elseif y and not step then
    if not M.is_int(y) then
      error(('(%s.range): Argument `y` is not an integer: `%s`'):format(MODSTR, y), ERROR)
    end
    step = x <= y and 1 or -1

    table.insert(range_list, x)
    for v = x + step, y, step do
      table.insert(range_list, v)
    end
  elseif y and step then
    if not M.is_int({ y, step }) then
      error(('(%s.range): Arguments `y` and/or `step` are not an integer!'):format(MODSTR), ERROR)
    end
    if step == 0 then
      error(('(%s.range): Argument `step` cannot be `0`!'):format(MODSTR), ERROR)
    end
    if x > y and step >= 1 then
      error(('(%s.range): Index out of bounds!'):format(MODSTR), ERROR)
    end
    if x > y and step <= -1 then
      local p = x
      x = y
      y = p
      step = step * -1
    end

    table.insert(range_list, x)
    for v = x + step, y, step do
      table.insert(range_list, v)
    end
  else
    error(('(%s.range): Argument `y` is nil while `step` is not: `%s`'):format(MODSTR, step), ERROR)
  end

  table.sort(range_list)
  return range_list
end

---Attempt to find out if given path is a hidden file.
---**Works only Windows, currently!**
---
---CREDITS:
---https://github.com/nvim-neo-tree/neo-tree.nvim/blob/8dd9f08ff086d09d112f1873f88dc0f74b598cdb/lua/neo-tree/utils/init.lua#L1299
--- ---
---@param path string
---@return boolean hidden
function M.is_hidden(path)
  M.validate({ path = { path, { 'string' } } })

  ---CREDITS: [u/Some_Derpy_Pineapple](https://www.reddit.com/r/neovim/comments/1nu5ehj/comment/ngyz21m/)
  local FILE_ATTRIBUTE_HIDDEN = 0x2
  local ffi = nil ---@type nil|ffilib
  if M.mod_exists('ffi') then
    ffi = require('ffi')
    ffi.cdef([[
      int GetFileAttributesA(const char *path);
    ]])
  end

  if M.is_windows() then
    if ffi then
      return bit.band(ffi.C.GetFileAttributesA(path), FILE_ATTRIBUTE_HIDDEN) ~= 0
    end
    return false -- FIXME: Find a reliable alternative
  end

  return false --- TODO: Find a reliable method for UNIX systems
end

---@param exe string[]|string
---@return boolean is_executable
function M.executable(exe)
  M.validate({ exe = { exe, { 'string', 'table' } } })

  ---@cast exe string
  if M.is_type('string', exe) then
    return vim.fn.executable(exe) == 1
  end

  local res = false

  ---@cast exe string[]
  for _, v in ipairs(exe) do
    res = M.executable(v)
    if not res then
      break
    end
  end
  return res
end

---@param tbl string[]
---@return string[] res
function M.delete_duplicates(tbl)
  M.validate({ tbl = { tbl, { 'table' } } })

  local cache_dict = {} ---@type table<string, integer>
  for _, v in ipairs(tbl) do
    local normalised_path = M.normalise_path(v)
    if cache_dict[normalised_path] == nil then
      cache_dict[normalised_path] = 1
    else
      cache_dict[normalised_path] = cache_dict[normalised_path] + 1
    end
  end

  local res = {} ---@type string[]
  for _, v in ipairs(tbl) do
    local normalised_path = M.normalise_path(v)
    if cache_dict[normalised_path] == 1 then
      table.insert(res, normalised_path)
    else
      cache_dict[normalised_path] = cache_dict[normalised_path] - 1
    end
  end
  return M.dedup(res)
end

---Left strip given a leading string (or list of strings) within a string, if any.
--- ---
---@param char string[]|string
---@param str string
---@return string new_str
function M.lstrip(char, str)
  M.validate({
    char = { char, { 'string', 'table' } },
    str = { str, { 'string' } },
  })

  if str == '' or not vim.startswith(str, char) then
    return str
  end

  ---@cast char string[]
  if M.is_type('table', char) then
    if not vim.tbl_isempty(char) then
      for _, c in ipairs(char) do
        str = M.lstrip(c, str)
      end
    end
    return str
  end

  ---@cast char string
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

---Right strip given a leading string (or list of strings) within a string, if any.
--- ---
---@param char string[]|string
---@param str string
---@return string new_str
function M.rstrip(char, str)
  M.validate({
    char = { char, { 'string', 'table' } },
    str = { str, { 'string' } },
  })

  if str == '' then
    return str
  end

  ---@cast char string[]
  if M.is_type('table', char) then
    if not vim.tbl_isempty(char) then
      for _, c in ipairs(char) do
        str = M.rstrip(c, str)
      end
    end
    return str
  end

  ---@cast char string
  str = str:reverse()

  if not vim.startswith(str, char) then
    return str:reverse()
  end
  return M.lstrip(char, str):reverse()
end

---Strip given a leading string (or list of strings) within a string, if any, bidirectionally.
--- ---
---@param char string[]|string
---@param str string
---@return string new_str
function M.strip(char, str)
  M.validate({
    char = { char, { 'string', 'table' } },
    str = { str, { 'string' } },
  })

  if str == '' then
    return str
  end

  ---@cast char string[]
  if M.is_type('table', char) then
    if not vim.tbl_isempty(char) then
      for _, c in ipairs(char) do
        str = M.strip(c, str)
      end
    end
    return str
  end

  ---@cast char string
  return M.rstrip(char, M.lstrip(char, str))
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
function M.dedup(T)
  M.validate({ T = { T, { 'table' } } })

  if empty(T) then
    return T
  end

  local NT = {}
  for _, v in pairs(T) do
    local not_dup = false
    if M.is_type('table', v) then
      not_dup = not in_tbl(NT, function(val)
        return vim.deep_equal(val, v)
      end, { predicate = true })
    else
      not_dup = not in_list(NT, v)
    end
    if not_dup then
      table.insert(NT, v)
    end
  end
  return NT
end

---@param t 'number'|'string'|'boolean'|'table'|'function'
---@param data nil|number|string|boolean|table|function
---@param sep? string
---@param constraints? string[]
---@return string
---@return boolean|nil
function M.format_per_type(t, data, sep, constraints)
  M.validate({
    t = { t, { 'string' } },
    sep = { sep, { 'string', 'nil' }, true },
    constraints = { constraints, { 'table', 'nil' }, true },
  })
  sep = sep or ''
  constraints = constraints or nil

  if t == 'string' then
    local res = ('%s`"%s"`'):format(sep, data)
    if not M.is_type('table', constraints) then
      return res
    end
    if constraints ~= nil and in_list(constraints, data) then
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
  for k, v in pairs(data) do
    k = M.is_type('number', k) and ('[%s]'):format(tostring(k)) or k
    msg = ('%s\n%s%s: '):format(msg, sep, k)
    if not M.is_type('string', v) then
      msg = ('%s%s'):format(msg, M.format_per_type(type(v), v, sep))
    else
      msg = ('%s`"%s"`'):format(msg, v)
    end
  end
  return msg
end

---@param path string
---@return boolean exists
function M.path_exists(path)
  M.validate({ path = { path, { 'string' } } })

  if M.dir_exists(path) then
    return true
  end

  --- CREDITS: @tomaskallup
  return vim.fn.empty(vim.fn.glob(path:gsub('%[', '\\['))) == 0
end

---@param path string
---@return string normalised_path
function M.normalise_path(path)
  M.validate({ path = { path, { 'string' } } })

  local normalised_path = path:gsub('\\', '/'):gsub('//', '/')
  if M.is_windows() then
    normalised_path = normalised_path:sub(1, 1):lower() .. normalised_path:sub(2)
  end
  return normalised_path
end

local Util = setmetatable(M, { ---@type Project.Utils.Util
  __index = M,
  __newindex = function()
    vim.notify('Project.Utils.Util is Read-Only!', vim.log.levels.ERROR)
  end,
})

return Util
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
