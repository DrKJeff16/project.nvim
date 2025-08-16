local Util = require('project.utils.util')
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
local Path = {}

---@param callback? fun(err: string|nil, success: boolean|nil)
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
    local exclude_dirs = require('project.config').options.exclude_dirs

    for _, dir_pattern in next, exclude_dirs do
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

function Path.init()
    local datapath = require('project.config').options.datapath

    if not Util.dir_exists(datapath) then
        datapath = vim.fn.stdpath('data')
    end

    Path.datapath = datapath
    Path.projectpath = string.format('%s/project_nvim', Path.datapath)
    Path.historyfile = string.format('%s/project_history', Path.projectpath)
end

return Path
