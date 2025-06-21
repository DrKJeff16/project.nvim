local config = require('project_nvim.config')
local uv = vim.uv or vim.loop

local DATAPATH = vim.fn.stdpath('data')
local PROJECTPATH = string.format('%s/project_nvim', DATAPATH)
local HISTFILE = string.format('%s/project_history', PROJECTPATH)

---@class Project.Utils.Path
---@field datapath string
---@field projectpath string
---@field historyfile string
---@field init fun(self: Project.Utils.Path)
---@field create_scaffolding fun(self: Project.Utils.Path, callback: (fun(err: string|nil, success: boolean|nil))?): uv.uv_fs_t
---@field is_excluded fun(dir: string): boolean
---@field exists fun(path: string): boolean

---@type Project.Utils.Path
---@diagnostic disable-next-line:missing-fields
local M = {}

M.datapath = DATAPATH -- directory
M.projectpath = PROJECTPATH -- directory
M.historyfile = HISTFILE -- file

---@param callback fun(err: string|nil, success: boolean|nil)
---@return uv.uv_fs_t
function M:create_scaffolding(callback)
    return uv.fs_mkdir(self.projectpath, tonumber('644', 8), callback)
end

---@param dir string
---@return boolean
function M.is_excluded(dir)
    for _, dir_pattern in next, config.options.exclude_dirs do
        if dir:match(dir_pattern) ~= nil then
            return true
        end
    end

    return false
end

---@param path string
---@return boolean
function M.exists(path) return vim.fn.empty(vim.fn.glob(path)) == 0 end

function M:init()
    self.datapath = require('project_nvim.config').options.datapath or DATAPATH
    self.projectpath = string.format('%s/project_nvim', self.datapath) -- directory
    self.historyfile = string.format('%s/project_history', self.projectpath) -- file

    self:create_scaffolding()
end

return M
