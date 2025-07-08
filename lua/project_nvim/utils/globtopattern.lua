---@diagnostic disable:missing-fields

-- Credits for this module goes to: David Manura
-- https://github.com/davidm/lua-glob-pattern

---@class Project.Utils.GlobPattern
---@field _TYPE string
---@field _NAME string
---@field _VERSION string
---@field globtopattern fun(g: string): (p: string)

---@type Project.Utils.GlobPattern
local Glob = { _TYPE = 'module', _NAME = 'globtopattern', _VERSION = '0.2.1.20120406' }

-- Some useful references:
-- - apr_fnmatch in Apache APR.  For example,
--   http://apr.apache.org/docs/apr/1.3/group__apr__fnmatch.html
--   which cites POSIX 1003.2-1992, section B.6.
---@param g string
---@return string p
function Glob.globtopattern(g)
    local p = '^' -- pattern being built
    local i = 0 -- index in g
    local c = '' -- char at index i in g.

    -- unescape glob char
    ---@return boolean
    local function unescape()
        if c == '\\' then
            i = i + 1
            c = g:sub(i, i)
            if c == '' then
                p = '[^]'
                return false
            end
        end
        return true
    end

    -- escape pattern char
    ---@param char string
    ---@return string
    local function escape(char)
        return char:match('^%w$') and c or '%' .. c
    end

    -- TODO(DrKJeff16): Let's simplify this in the future
    -- Convert tokens at end of charset.
    ---@return boolean
    local function charset_end()
        while true do
            if c == '' then
                p = '[^]'
                return false
            elseif c == ']' then
                p = p .. ']'
                break
            else
                if not unescape() then
                    break
                end
                local c1 = c
                i = i + 1
                c = g:sub(i, i)
                if c == '' then
                    p = '[^]'
                    return false
                elseif c == '-' then
                    i = i + 1
                    c = g:sub(i, i)
                    if c == '' then
                        p = '[^]'
                        return false
                    elseif c == ']' then
                        p = p .. escape(c1) .. '%-]'
                        break
                    else
                        if not unescape() then
                            break
                        end
                        p = p .. escape(c1) .. '-' .. escape(c)
                    end
                elseif c == ']' then
                    p = p .. escape(c1) .. ']'
                    break
                else
                    p = p .. escape(c1)
                    i = i - 1 -- put back
                end
            end
            i = i + 1
            c = g:sub(i, i)
        end
        return true
    end

    -- Convert tokens in charset.
    ---@return boolean
    local function charset()
        i = i + 1
        c = g:sub(i, i)
        if c == '' or c == ']' then
            p = '[^]'
            return false
        elseif c == '^' or c == '!' then
            i = i + 1
            c = g:sub(i, i)
            if c == ']' then
            -- ignored
            else
                p = p .. '[^'
                if not charset_end() then
                    return false
                end
            end
        else
            p = p .. '['
            if not charset_end() then
                return false
            end
        end
        return true
    end

    -- Convert tokens.
    while true do
        i = i + 1
        c = g:sub(i, i)
        if c == '' then
            p = p .. '$'
            break
        elseif c == '?' then
            p = p .. '.'
        elseif c == '*' then
            p = p .. '.*'
        elseif c == '[' then
            if not charset() then
                break
            end
        elseif c == '\\' then
            i = i + 1
            c = g:sub(i, i)
            if c == '' then
                p = p .. '\\$'
                break
            end
            p = p .. escape(c)
        else
            p = p .. escape(c)
        end
    end

    return p
end

return Glob
