---@diagnostic disable:missing-fields

---@module 'project_nvim.config'
---@module 'project_nvim.project'

-- `project_nvim` module
---@class Project
---@field setup fun(options: table|Project.Config.Options?)
---@field get_recent_projects fun(): table|string[]
---@field get_history_paths fun(path: ('datapath'|'projectpath'|'historyfile')?): string|HistoryPaths
---@field get_config fun(): Project.Config.Options|nil
---@field get_project_root fun(): (string?,string?)

local Util = require('project_nvim.utils.util')

local is_type = Util.is_type

---@type Project
local Project = {}

---@param options? table|Project.Config.Options
function Project.setup(options)
    options = is_type('table', options) and options or {}

    require('project_nvim.config').setup(options)
end

-- CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/112
Project.get_project_root = require('project_nvim.project').get_project_root

Project.get_history_paths = require('project_nvim.project').get_history_paths

---@return table|string[]
function Project.get_recent_projects()
    return require('project_nvim.utils.history').get_recent_projects()
end

---@return Project.Config.Options|nil
function Project.get_config()
    local Config = require('project_nvim.config')

    return Config.setup_called and Config.options or nil
end

return Project
