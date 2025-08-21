---Credits for this module goes to: David Manura:
---https://github.com/davidm/lua-glob-pattern
--- ---
---@class Project.Utils.GlobPattern
local Glob = {}

---Some useful references:
--- - apr_fnmatch in Apache APR.  For example,
---   http://apr.apache.org/docs/apr/1.3/group__apr__fnmatch.html
---   which cites POSIX 1003.2-1992, section B.6.
---@param g string
---@return string pattern
function Glob.globtopattern(g)
    local pattern, i, c = '^', 0, ''

    ---Unescape glob char.
    --- ---
    ---@return boolean
    local function unescape()
        if c == '\\' then
            i = i + 1
            c = g:sub(i, i)
            if c == '' then
                pattern = '[^]'
                return false
            end
        end
        return true
    end

    ---Escape pattern char.
    --- ---
    ---@param char string
    ---@return string
    local function escape(char)
        return char:match('^%w$') and c or '%' .. c
    end

    --- TODO: Let's simplify this in the future

    ---Convert tokens at end of charset.
    --- ---
    ---@return boolean
    local function charset_end()
        while true do
            if c == '' then
                pattern = '[^]'
                return false
            elseif c == ']' then
                pattern = pattern .. ']'
                break
            else
                if not unescape() then
                    break
                end
                local c1 = c
                i = i + 1
                c = g:sub(i, i)
                if c == '' then
                    pattern = '[^]'
                    return false
                elseif c == '-' then
                    i = i + 1
                    c = g:sub(i, i)
                    if c == '' then
                        pattern = '[^]'
                        return false
                    elseif c == ']' then
                        pattern = pattern .. escape(c1) .. '%-]'
                        break
                    else
                        if not unescape() then
                            break
                        end
                        pattern = pattern .. escape(c1) .. '-' .. escape(c)
                    end
                elseif c == ']' then
                    pattern = pattern .. escape(c1) .. ']'
                    break
                else
                    pattern = pattern .. escape(c1)
                    i = i - 1 -- put back
                end
            end
            i = i + 1
            c = g:sub(i, i)
        end
        return true
    end

    ---Convert tokens in charset.
    --- ---
    ---@return boolean
    local function charset()
        i = i + 1
        c = g:sub(i, i)
        if c == '' or c == ']' then
            pattern = '[^]'
            return false
        elseif c == '^' or c == '!' then
            i = i + 1
            c = g:sub(i, i)
            if c == ']' then
            -- ignored
            else
                pattern = pattern .. '[^'
                if not charset_end() then
                    return false
                end
            end
        else
            pattern = pattern .. '['
            if not charset_end() then
                return false
            end
        end
        return true
    end

    ---Convert tokens.
    while true do
        i = i + 1
        c = g:sub(i, i)
        if c == '' then
            pattern = pattern .. '$'
            break
        elseif c == '?' then
            pattern = pattern .. '.'
        elseif c == '*' then
            pattern = pattern .. '.*'
        elseif c == '[' then
            if not charset() then
                break
            end
        elseif c == '\\' then
            i = i + 1
            c = g:sub(i, i)
            if c == '' then
                pattern = pattern .. '\\$'
                break
            end
            pattern = pattern .. escape(c)
        else
            pattern = pattern .. escape(c)
        end
    end

    return pattern
end

---@param pattern string
---@return string pattern
function Glob.pattern_exclude(pattern)
    local HOME = vim.fn.expand('~')
    local pattern_len = string.len(pattern)

    if vim.startswith(pattern, '~/') then
        pattern = string.format('%s/%s', HOME, pattern:sub(3, pattern_len))
    end

    pattern = Glob.globtopattern(pattern)

    return pattern
end

return Glob
