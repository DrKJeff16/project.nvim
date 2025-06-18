local config = require('project_nvim.config')
local uv = vim.uv or vim.loop

---@class Project.Utils.Path
---@field datapath string
---@field projectpath string
---@field historyfile string
---@field init fun()
---@field create_scaffolding fun(callback: (fun(err: string|nil, success: boolean|nil))?)
---@field is_excluded fun(dir: string): boolean
---@field exists fun(path: string): boolean

---@type Project.Utils.Path
---@diagnostic disable-next-line:missing-fields
local M = {}

M.datapath = vim.fn.stdpath('data') -- directory
M.projectpath = M.datapath .. '/project_nvim' -- directory
M.historyfile = M.projectpath .. '/project_history' -- file

function M.init()
    M.datapath = config.options.datapath
    M.projectpath = M.datapath .. '/project_nvim' -- directory
    M.historyfile = M.projectpath .. '/project_history' -- file
end

---@param callback fun(err: string|nil, success: boolean|nil)
function M.create_scaffolding(callback)
    uv.fs_mkdir(M.projectpath, 448, callback ~= nil and callback or nil)
end

---@param dir string
---@return boolean
function M.is_excluded(dir)
    for _, dir_pattern in ipairs(config.options.exclude_dirs) do
        if dir:match(dir_pattern) ~= nil then
            return true
        end
    end

    return false
end

---@param path string
---@return boolean
function M.exists(path) return vim.fn.empty(vim.fn.glob(path)) == 0 end

return M
