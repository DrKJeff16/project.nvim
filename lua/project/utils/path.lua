local MODSTR = 'project.utils.path'
local uv = vim.uv or vim.loop

local vim_has = require('project.utils.util').vim_has

---@class Project.Utils.Path
---The directory where the project dir will be saved.
--- ---
---@field datapath? string
---The directory where the project history will be saved.
--- ---
---@field projectpath? string
---The project history file.
--- ---
---@field historyfile? string
local Path = {}
Path.last_dir_cache = ''
Path.curr_dir_cache = {} ---@type string[]
Path.exists = require('project.utils.util').path_exists

---@param file_dir string
function Path.get_files(file_dir)
    if vim_has('nvim-0.11') then
        vim.validate('file_dir', file_dir, 'string', false)
    else
        vim.validate({ file_dir = { file_dir, { 'string' } } })
    end
    Path.last_dir_cache = file_dir
    Path.curr_dir_cache = {}
    local dir = uv.fs_scandir(file_dir)
    if not dir then
        return
    end
    while true do
        local file = uv.fs_scandir_next(dir)
        if not file then
            return
        end
        table.insert(Path.curr_dir_cache, file)
    end
end

---@param dir string
---@param identifier string
function Path.has(dir, identifier)
    if vim_has('nvim-0.11') then
        vim.validate('dir', dir, 'string', false)
        vim.validate('identifier', identifier, 'string', false)
    else
        vim.validate({
            dir = { dir, { 'string' } },
            identifier = { identifier, { 'string' } },
        })
    end
    local globtopattern = require('project.utils.globtopattern').globtopattern
    if Path.last_dir_cache ~= dir then
        Path.get_files(dir)
    end

    local pattern = globtopattern(identifier)
    for _, file in ipairs(Path.curr_dir_cache) do
        if file:match(pattern) ~= nil then
            return true
        end
    end
    return false
end

---@param dir string
---@param identifier string
---@return boolean
function Path.is(dir, identifier)
    if vim_has('nvim-0.11') then
        vim.validate('dir', dir, 'string', false)
        vim.validate('identifier', identifier, 'string', false)
    else
        vim.validate({
            dir = { dir, { 'string' } },
            identifier = { identifier, { 'string' } },
        })
    end
    return dir:match('.*/(.*)') == identifier
end

---@param path_str string
---@return string|'/'
function Path.get_parent(path_str)
    if vim_has('nvim-0.11') then
        vim.validate('path_str', path_str, 'string', false)
    else
        vim.validate({ path_str = { path_str, { 'string' } } })
    end
    path_str = path_str:match('^(.*)/') ---@type string
    return (path_str ~= '') and path_str or '/'
end

---@param dir string
---@param identifier string
---@return boolean
function Path.sub(dir, identifier)
    if vim_has('nvim-0.11') then
        vim.validate('dir', dir, 'string', false)
        vim.validate('identifier', identifier, 'string', false)
    else
        vim.validate({
            dir = { dir, { 'string' } },
            identifier = { identifier, { 'string' } },
        })
    end
    local path_str = Path.get_parent(dir)
    local current
    while true do
        if Path.is(path_str, identifier) then
            return true
        end
        current, path_str = path_str, Path.get_parent(path_str)
        if current == path_str then
            return false
        end
    end
end

---@param dir string
---@param identifier string
---@return boolean
function Path.child(dir, identifier)
    if vim_has('nvim-0.11') then
        vim.validate('dir', dir, 'string', false)
        vim.validate('identifier', identifier, 'string', false)
    else
        vim.validate({
            dir = { dir, { 'string' } },
            identifier = { identifier, { 'string' } },
        })
    end
    return Path.is(Path.get_parent(dir), identifier)
end

---@param dir string
---@param pattern string
---@return boolean
function Path.match(dir, pattern)
    if vim_has('nvim-0.11') then
        vim.validate('dir', dir, 'string', false)
        vim.validate('pattern', pattern, 'string', false)
    else
        vim.validate({
            dir = { dir, { 'string' } },
            pattern = { pattern, { 'string' } },
        })
    end

    local SWITCH = {
        ['='] = Path.is,
        ['^'] = Path.sub,
        ['>'] = Path.child,
    }
    local first_char = pattern:sub(1, 1)
    for char, case in pairs(SWITCH) do
        if first_char == char then
            return case(dir, pattern:sub(2))
        end
    end
    return Path.has(dir, pattern)
end

---@param path? string
function Path.create_path(path)
    if vim_has('nvim-0.11') then
        vim.validate('path', path, 'string', true)
    else
        vim.validate({ path = { path, { 'string' }, true } })
    end
    path = path or Path.projectpath

    if not Path.exists(path) then
        local Log = require('project.utils.log')
        Log.debug(('(%s.create_path): Creating directory `%s`.'):format(MODSTR, path))
        uv.fs_mkdir(path, tonumber('755', 8))
    end
end

---@param dir string
---@return string|nil
---@return string|nil
function Path.root_included(dir)
    if vim_has('nvim-0.11') then
        vim.validate('dir', dir, 'string', false)
    else
        vim.validate({ dir = { dir, { 'string' } } })
    end
    local Config = require('project.config')
    while true do ---Breadth-First search
        for _, pattern in ipairs(Config.options.patterns) do
            local excluded = false
            if pattern:sub(1, 1) == '!' then
                excluded, pattern = true, pattern:sub(2)
            end
            if Path.match(dir, pattern) then
                if not excluded then
                    return dir, 'pattern ' .. pattern
                end
                break
            end
        end
        local parent = Path.get_parent(dir)
        if not parent or parent == dir then
            return
        end
        dir = parent
    end
end

---@param dir string
---@return boolean
function Path.is_excluded(dir)
    if vim_has('nvim-0.11') then
        vim.validate('dir', dir, 'string', false)
    else
        vim.validate({ dir = { dir, { 'string' } } })
    end
    local exclude_dirs = require('project.config').options.exclude_dirs
    for _, excluded in ipairs(exclude_dirs) do
        if dir:match(excluded) ~= nil then
            return true
        end
    end
    return false
end

function Path.init()
    local datapath = require('project.config').options.datapath
    if not Path.exists(datapath) then
        datapath = vim.fn.stdpath('data')
    end
    Path.datapath = datapath
    Path.projectpath = ('%s/project_nvim'):format(Path.datapath)
    Path.historyfile = ('%s/project_history'):format(Path.projectpath)
end

return Path
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
