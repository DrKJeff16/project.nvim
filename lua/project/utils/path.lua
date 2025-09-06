local fmt = string.format
local validate = vim.validate

local Util = require('project.utils.util')

local dir_exists = Util.dir_exists

local uv = vim.uv or vim.loop

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
---@field last_dir_cache? string
---@field curr_dir_cache? string[]
local Path = {}

---@param file_dir string
function Path.get_files(file_dir)
    validate('file_dir', file_dir, 'string', false)

    Path.last_dir_cache = file_dir
    Path.curr_dir_cache = {}

    ---@type uv.uv_fs_t|nil
    local dir = uv.fs_scandir(file_dir)
    if dir == nil then
        return
    end

    ---@type string|nil
    local file

    while true do
        file = uv.fs_scandir_next(dir)
        if file == nil then
            return
        end

        table.insert(Path.curr_dir_cache, file)
    end
end

---@param dir string
---@param identifier string
function Path.has(dir, identifier)
    local globtopattern = require('project.utils.globtopattern').globtopattern

    if Path.last_dir_cache ~= dir then
        Path.get_files(dir)
    end

    local pattern = globtopattern(identifier)

    for _, file in next, Path.curr_dir_cache do
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
    return dir:match('.*/(.*)') == identifier
end

---@param path_str string
---@return string|'/'
function Path.get_parent(path_str)
    path_str = path_str:match('^(.*)/')
    vim.notify(fmt('Parent: %s', path_str or '/'))
    return (path_str ~= '') and path_str or '/' ---@cast path_str  string
end

---@param dir string
---@param identifier string
---@return boolean
function Path.sub(dir, identifier)
    local path_str = Path.get_parent(dir)
    local current

    ---FIXME: (DrKJeff16) This loop is dangerous, even if halting cond is supposedly known
    while true do
        if Path.is(path_str, identifier) then
            return true
        end

        current = path_str
        path_str = Path.get_parent(path_str)

        if current == path_str then
            return false
        end
    end
end

---@param dir string
---@param identifier string
---@return boolean
function Path.child(dir, identifier)
    return Path.is(Path.get_parent(dir), identifier)
end

---@param dir string
---@param pattern string
---@return boolean
function Path.match(dir, pattern)
    local SWITCH = {
        ['='] = Path.is,
        ['^'] = Path.sub,
        ['>'] = Path.child,
    }

    local first_char = pattern:sub(1, 1)

    for char, case in next, SWITCH do
        if first_char == char then
            return case(dir, pattern:sub(2))
        end
    end

    return Path.has(dir, pattern)
end

---@param callback? fun(err?: string, success?: boolean)
function Path.create_scaffolding(callback)
    local flag = tonumber('755', 8)

    if callback ~= nil then
        uv.fs_mkdir(Path.projectpath, flag, callback)
    else
        uv.fs_mkdir(Path.projectpath, flag)
    end
end

---@param dir string
---@return string|nil
---@return string|nil
function Path.root_included(dir)
    validate('dir', dir, 'string', false)

    local Config = require('project.config')

    ---Breadth-First search
    while true do ---FIXME: This loop is dangerous, even if halting cond is supposedly known
        for _, pattern in next, Config.options.patterns do
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

        if parent == nil or parent == dir then
            return nil
        end

        dir = parent
    end
end

---@param dir string
---@return boolean
function Path.is_excluded(dir)
    local exclude_dirs = require('project.config').options.exclude_dirs

    for _, excluded in next, exclude_dirs do
        ---FIXME: This needs revision
        if dir:match(excluded) ~= nil then
            return true
        end
    end

    return false
end

---@param path string
---@return boolean
function Path.exists(path)
    --- CREDITS: @tomaskallup
    return vim.fn.empty(vim.fn.glob(path:gsub('%[', '\\['))) == 0
end

function Path.init()
    local datapath = require('project.config').options.datapath

    if not dir_exists(datapath) then
        datapath = vim.fn.stdpath('data')
    end

    Path.datapath = datapath
    Path.projectpath = fmt('%s/project_nvim', Path.datapath)
    Path.historyfile = fmt('%s/project_history', Path.projectpath)
end

return Path

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
