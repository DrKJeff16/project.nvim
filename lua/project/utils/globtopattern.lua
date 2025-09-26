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

---Some useful references:
--- - [`apr_fnmatch`](http://apr.apache.org/docs/apr/1.3/group__apr__fnmatch.html)
--- ---
---@param glob string
---@return string pattern
function Glob.globtopattern(glob)
    local pattern = '^'
    local i = 0
    local char = ''

    local function unescape()
        if char == '\\' then
            i = i + 1
            char = glob:sub(i, i)
            if char == '' then
                pattern = '[^]'
                return false
            end
        end
        return true
    end

    ---Convert tokens at end of charset.
    --- ---
    ---@return boolean
    local function charset_end()
        while true do
            if char == '' then
                pattern = '[^]'
                return false
            elseif char == ']' then
                pattern = ('%s]'):format(pattern)
                break
            else
                if not unescape() then
                    break
                end
                local c1 = char
                i = i + 1
                char = glob:sub(i, i)
                if char == '' then
                    pattern = '[^]'
                    return false
                elseif char == '-' then
                    i = i + 1
                    char = glob:sub(i, i)
                    if char == '' then
                        pattern = '[^]'
                        return false
                    elseif char == ']' then
                        pattern = ('%s%s'):format(pattern, Glob.escape(c1, char)) .. '%-]'
                        break
                    else
                        if not unescape() then
                            break
                        end
                        pattern = ('%s%s-%s'):format(
                            pattern,
                            Glob.escape(c1, char),
                            Glob.escape(char, char)
                        )
                    end
                elseif char == ']' then
                    pattern = ('%s%s]'):format(pattern, Glob.escape(c1, char))
                    break
                else
                    pattern = ('%s%s'):format(pattern, Glob.escape(c1, char))
                    i = i - 1 -- put back
                end
            end
            i = i + 1
            char = glob:sub(i, i)
        end
        return true
    end

    ---Convert tokens in charset.
    --- ---
    ---@return boolean
    local function charset()
        i = i + 1
        char = glob:sub(i, i)
        if in_list({ '', ']' }, char) then
            pattern = '[^]'
            return false
        elseif in_list({ '^', '!' }, char) then
            i = i + 1
            char = glob:sub(i, i)
            if char ~= ']' then
                pattern = ('%s[^'):format(pattern)
                if not charset_end() then
                    return false
                end
            end
        else
            pattern = ('%s['):format(pattern)
            if not charset_end() then
                return false
            end
        end
        return true
    end

    while true do
        i = i + 1
        char = glob:sub(i, i)
        if char == '' then
            pattern = ('%s$'):format(pattern)
            break
        elseif char == '?' then
            pattern = ('%s.'):format(pattern)
        elseif char == '*' then
            pattern = ('%s.*'):format(pattern)
        elseif char == '[' then
            if not charset() then
                break
            end
        elseif char == '\\' then
            i = i + 1
            char = glob:sub(i, i)
            if char == '' then
                pattern = ('%s\\$'):format(pattern)
                break
            end
            pattern = ('%s%s'):format(pattern, Glob.escape(char, char))
        else
            pattern = ('%s%s'):format(pattern, Glob.escape(char, char))
        end
    end
    return pattern
end

---@param pattern string
---@return string pattern
function Glob.pattern_exclude(pattern)
    local HOME = vim.fn.expand('~')
    local pattern_len = pattern:len()
    if vim.startswith(pattern, '~/') then
        pattern = ('%s/%s'):format(HOME, pattern:sub(3, pattern_len))
    end
    return Glob.globtopattern(pattern)
end

return Glob
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
