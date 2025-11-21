local in_list = vim.list_contains

---Credits for this module goes to [David Manura](https://github.com/davidm/lua-glob-pattern).
--- ---
---@class Project.Utils.Glob
local Glob = {}

---Escape pattern char.
--- ---
---@param char string
---@return string
function Glob.escape(char, c)
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
function Glob.unescape(glob, char, pattern, i)
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
function Glob.charset_end(glob, char, pattern, i)
    local un = false
    while true do
        if char:len() == 0 then
            return false, char, '[^]', i
        end
        if char == ']' then
            return true, char, ('%s]'):format(pattern), i
        end
        un, char, pattern, i = Glob.unescape(glob, char, pattern, i)
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
            return true, char, ('%s%s]'):format(pattern, Glob.escape(c1, char)), i
        end
        if char ~= '-' then
            pattern = ('%s%s'):format(pattern, Glob.escape(c1, char))
            i = i - 1 -- put back
        else
            i = i + 1
            char = glob:sub(i, i)
            if char:len() == 0 then
                return false, char, '[^]', i
            end
            if char == ']' then
                return true, char, ('%s%s'):format(pattern, Glob.escape(c1, char)) .. '%-]', i
            end
            un, char, pattern, i = Glob.unescape(glob, char, pattern, i)
            if not un then
                return true, char, pattern, i
            end
            pattern = ('%s%s-%s'):format(pattern, Glob.escape(c1, char), Glob.escape(char, char))
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
function Glob.charset(glob, char, pattern, i)
    local chs_end = false
    i = i + 1
    char = glob:sub(i, i)
    if in_list({ '', ']' }, char) then
        return false, char, '[^]', i
    end
    if in_list({ '^', '!' }, char) then
        i = i + 1
        char = glob:sub(i, i)
        if char ~= ']' then
            pattern = ('%s[^'):format(pattern)
            chs_end, char, pattern, i = Glob.charset_end(glob, char, pattern, i)
            if not chs_end then
                return false, char, pattern, i
            end
        end
    else
        pattern = ('%s['):format(pattern)
        chs_end, char, pattern, i = Glob.charset_end(glob, char, pattern, i)
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
function Glob.globtopattern(glob)
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
            chs, char, pattern, i = Glob.charset(glob, char, pattern, i)
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
            pattern = ('%s%s'):format(pattern, Glob.escape(char, char))
        end
    end
end

---@param pattern string
---@return string pattern
function Glob.pattern_exclude(pattern)
    if vim.startswith(pattern, '~/') then
        pattern = ('%s/%s'):format(vim.fn.expand('~'), pattern:sub(3, pattern:len()))
    end
    return Glob.globtopattern(pattern)
end

return Glob
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
