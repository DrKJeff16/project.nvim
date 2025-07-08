local uv = vim.uv or vim.loop

local DATAPATH = vim.fn.stdpath('data')

---@class Project.Utils.Path
-- The `datapath` value, specified in `project_nvim.setup()`
-- ---
-- Default: `vim.fn.stdpath('data')`
-- ---
---@field datapath string
-- The directory in which the project history is saved
---@field projectpath string
-- The project history file
---@field historyfile string
---@field init fun(self: Project.Utils.Path)
---@field create_scaffolding fun(callback: (fun(err: string|nil, success: boolean|nil))?)
---@field is_excluded fun(dir: string): (res: boolean)
---@field exists fun(path: string): boolean

---@type Project.Utils.Path
---@diagnostic disable-next-line:missing-fields
local Path = {}

-- The `datapath` value, specified in `project_nvim.setup()`
-- ---
-- Default: `vim.fn.stdpath('data')`
-- ---
Path.datapath = DATAPATH
-- The directory in which the project history is saved
Path.projectpath = string.format('%s/project_nvim', Path.datapath)
-- The project history file
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
---@return boolean res
function Path.is_excluded(dir)
    local Config = require('project_nvim.config')

    local res = false

    for _, dir_pattern in next, Config.options.exclude_dirs do
        if dir:match(dir_pattern) ~= nil then
            res = true
            break
        end
    end

    return res
end

---@param path string
---@return boolean
function Path.exists(path) return vim.fn.empty(vim.fn.glob(path)) == 0 end

function Path:init()
    local Config = require('project_nvim.config')

    self.datapath = Config.options.datapath or DATAPATH
    self.projectpath = string.format('%s/project_nvim', self.datapath)
    self.historyfile = string.format('%s/project_history', self.projectpath)
end

return Path
