---Credits for this module goes to [David Manura](https://github.com/davidm/lua-glob-pattern).
--- ---
---@class Project.Utils.Glob
local M = {}

---Escape pattern char.
--- ---
---@param char string
---@return string escaped_char
function M.escape(char, c)
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
function M.unescape(glob, char, pattern, i)
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
function M.charset_end(glob, char, pattern, i)
  local un = false
  while true do
    if char:len() == 0 then
      return false, char, '[^]', i
    end
    if char == ']' then
      return true, char, ('%s]'):format(pattern), i
    end
    un, char, pattern, i = M.unescape(glob, char, pattern, i)
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
      return true, char, ('%s%s]'):format(pattern, M.escape(c1, char)), i
    end
    if char ~= '-' then
      pattern = ('%s%s'):format(pattern, M.escape(c1, char))
      i = i - 1 -- put back
    else
      i = i + 1
      char = glob:sub(i, i)
      if char:len() == 0 then
        return false, char, '[^]', i
      end
      if char == ']' then
        return true, char, ('%s%s'):format(pattern, M.escape(c1, char)) .. '%-]', i
      end
      un, char, pattern, i = M.unescape(glob, char, pattern, i)
      if not un then
        return true, char, pattern, i
      end
      pattern = ('%s%s-%s'):format(pattern, M.escape(c1, char), M.escape(char, char))
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
function M.charset(glob, char, pattern, i)
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
      pattern = ('%s[^'):format(pattern)
      chs_end, char, pattern, i = M.charset_end(glob, char, pattern, i)
      if not chs_end then
        return false, char, pattern, i
      end
    end
  else
    pattern = ('%s['):format(pattern)
    chs_end, char, pattern, i = M.charset_end(glob, char, pattern, i)
    if not chs_end then
      return false, char, pattern, i
    end
  end
  return true, char, pattern, i
end

---Some useful references:
--- - [`apr_fnmatch`](http://apr.apache.org/docs/apr/1.3/group__apr__fnmatch.html)
--- ---
---@param glob string
---@return string pattern
function M.globtopattern(glob)
  local pattern = '^'
  local i = 0
  local char = ''
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
      chs, char, pattern, i = M.charset(glob, char, pattern, i)
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
      pattern = ('%s%s'):format(pattern, M.escape(char, char))
    end
  end
end

---@param pattern string
---@return string pattern
function M.pattern_exclude(pattern)
  if vim.startswith(pattern, '~/') then
    pattern = ('%s/%s'):format(vim.fn.expand('~'), pattern:sub(3, pattern:len()))
  end
  return M.globtopattern(pattern)
end

local Glob = setmetatable(M, { ---@type Project.Utils.Glob
  __index = M,
  __newindex = function()
    vim.notify('User.Utils.Glob is Read-Only!', vim.log.levels.ERROR)
  end,
})

return Glob
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
