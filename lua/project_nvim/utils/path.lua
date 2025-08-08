local uv = vim.uv or vim.loop

local DATAPATH = vim.fn.stdpath('data')

---@class Project.Utils.Path
local Path = {}

--- The directory where the project dir will be saved.
--- ---
Path.datapath = DATAPATH

--- The directory where the project history will be saved.
--- ---
Path.projectpath = string.format('%s/project_nvim', Path.datapath)

--- The project history file.
---
Path.historyfile = string.format('%s/project_history', Path.projectpath)

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

function Path.init()
    local Config = require('project_nvim.config')

    Path.datapath = Config.options.datapath or DATAPATH
    Path.projectpath = string.format('%s/project_nvim', Path.datapath)
    Path.historyfile = string.format('%s/project_history', Path.projectpath)
end

return Path
