local Util = require('project.util')

---Escape pattern char.
--- ---
---@param char string
---@param c string
---@return string escaped_char
local function escape(char, c)
  Util.validate({
    char = { char, { 'string' } },
    c = { c, { 'string' } },
  })

  return char:match('^%w$') and c or ('%' .. c)
end

---@param glob string
---@param char string
---@param pattern string
---@param i integer
---@return boolean
---@return string char
---@return string pattern
---@return integer i
local function unescape(glob, char, pattern, i)
  Util.validate({
    glob = { glob, { 'string' } },
    char = { char, { 'string' } },
    pattern = { pattern, { 'string' } },
    i = { i, { 'number' } },
  })

  if char ~= '\\' then
    return true, char, pattern, i
  end

  i = i + 1
  char = glob:sub(i, i)
  if char:len() == 0 then
    return false, char, '[^]', i
  end
  return true, char, pattern, i
end

---Convert tokens at end of charset.
--- ---
---@param glob string
---@param char string
---@param pattern string
---@param i integer
---@return boolean
---@return string char
---@return string pattern
---@return integer i
local function charset_end(glob, char, pattern, i)
  Util.validate({
    glob = { glob, { 'string' } },
    char = { char, { 'string' } },
    pattern = { pattern, { 'string' } },
    i = { i, { 'number' } },
  })

  local un = false
  while true do
    if char:len() == 0 then
      return false, char, '[^]', i
    end
    if char == ']' then
      return true, char, ('%s]'):format(pattern), i
    end
    un, char, pattern, i = unescape(glob, char, pattern, i)
    if not un then
      return true, char, pattern, i
    end
    local c1 = char
    i = i + 1
    char = glob:sub(i, i)
    if char:len() == 0 then
      return false, char, '[^]', i
    end
    if char == ']' then
      return true, char, ('%s%s]'):format(pattern, escape(c1, char)), i
    end
    if char ~= '-' then
      pattern, i = ('%s%s'):format(pattern, escape(c1, char)), i - 1
    else
      i = i + 1
      char = glob:sub(i, i)
      if char:len() == 0 then
        return false, char, '[^]', i
      end
      if char == ']' then
        return true, char, ('%s%s'):format(pattern, escape(c1, char)) .. '%-]', i
      end
      un, char, pattern, i = unescape(glob, char, pattern, i)
      if not un then
        return true, char, pattern, i
      end
      pattern = ('%s%s-%s'):format(pattern, escape(c1, char), escape(char, char))
    end
    i = i + 1
    char = glob:sub(i, i)
  end
end

---Convert tokens in charset.
--- ---
---@param glob string
---@param char string
---@param pattern string
---@param i integer
---@return boolean
---@return string char
---@return string pattern
---@return integer i
local function charset(glob, char, pattern, i)
  Util.validate({
    glob = { glob, { 'string' } },
    char = { char, { 'string' } },
    pattern = { pattern, { 'string' } },
    i = { i, { 'number' } },
  })

  local chs_end = false
  i = i + 1
  char = glob:sub(i, i)
  if vim.list_contains({ '', ']' }, char) then
    return false, char, '[^]', i
  end
  if vim.list_contains({ '^', '!' }, char) then
    i = i + 1
    char = glob:sub(i, i)
    if char ~= ']' then
      chs_end, char, pattern, i = charset_end(glob, char, ('%s[^'):format(pattern), i)
      if not chs_end then
        return false, char, pattern, i
      end
    end
  else
    chs_end, char, pattern, i = charset_end(glob, char, ('%s['):format(pattern), i)
    if not chs_end then
      return false, char, pattern, i
    end
  end
  return true, char, pattern, i
end

---Credits for this module goes to [David Manura](https://github.com/davidm/lua-glob-pattern).
--- ---
---@class Project.Util.Glob
local M = {}

---Some useful references:
--- - [`apr_fnmatch`](http://apr.apache.org/docs/apr/1.3/group__apr__fnmatch.html)
--- ---
---@param glob string
---@return string pattern
function M.globtopattern(glob)
  Util.validate({ glob = { glob, { 'string' } } })

  local pattern, i, char = '^', 0, ''
  while true do
    local chs = false
    i = i + 1
    char = glob:sub(i, i)
    if char:len() == 0 then
      return ('%s$'):format(pattern)
    end
    if char == '?' then
      pattern = ('%s.'):format(pattern)
    elseif char == '*' then
      pattern = ('%s.*'):format(pattern)
    elseif char == '[' then
      chs, char, pattern, i = charset(glob, char, pattern, i)
      if not chs then
        return pattern
      end
    else
      if char == '\\' then
        i = i + 1
        char = glob:sub(i, i)
        if char:len() == 0 then
          return ('%s\\$'):format(pattern)
        end
      end
      pattern = ('%s%s'):format(pattern, escape(char, char))
    end
  end
end

---@param pattern string
---@return string pattern
function M.pattern_exclude(pattern)
  Util.validate({ pattern = { pattern, { 'string' } } })

  return M.globtopattern(
    vim.startswith(pattern, '~/')
        and ('%s%s%s'):format(vim.fn.expand('~'), Util.is_windows() and '\\' or '/', pattern:sub(3, pattern:len()))
      or pattern
  )
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
