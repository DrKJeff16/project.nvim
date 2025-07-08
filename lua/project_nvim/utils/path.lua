local uv = vim.uv or vim.loop

local DATAPATH = vim.fn.stdpath('data')

---@class Project.Utils.Path
---@field datapath string
---@field projectpath string
---@field historyfile string
---@field init fun(self: Project.Utils.Path)
---@field create_scaffolding fun(callback: (fun(err: string|nil, success: boolean|nil))?)
---@field is_excluded fun(dir: string): boolean
---@field exists fun(path: string): boolean

---@type Project.Utils.Path
---@diagnostic disable-next-line:missing-fields
local Path = {}

Path.datapath = DATAPATH -- directory
Path.projectpath = string.format('%s/project_nvim', Path.datapath)
Path.historyfile = string.format('%s/project_history', Path.projectpath)

---@param callback fun(err: string|nil, success: boolean|nil)
function Path.create_scaffolding(callback)
    local flag = tonumber('755', 8)

    if callback ~= nil then
        uv.fs_mkdir(Path.projectpath, flag, callback)
    else
        uv.fs_mkdir(Path.projectpath, flag)
    end
end

---@param dir string
---@return boolean
function Path.is_excluded(dir)
    local Config = require('project_nvim.config')

    for _, dir_pattern in next, Config.options.exclude_dirs do
        if dir:match(dir_pattern) ~= nil then
            return true
        end
    end

    return false
end

---@param path string
---@return boolean
function Path.exists(path)
    return vim.fn.empty(vim.fn.glob(path)) == 0
end

function Path:init()
    local Config = require('project_nvim.config')

    self.datapath = Config.options.datapath or DATAPATH
    self.projectpath = string.format('%s/project_nvim', self.datapath) -- directory
    self.historyfile = string.format('%s/project_history', self.projectpath) -- file
end

return Path
