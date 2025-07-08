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

---@type Project
local Project = {}

Project.setup = require('project_nvim.config').setup

-- CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/112
Project.get_project_root = require('project_nvim.project').get_project_root

Project.get_history_paths = require('project_nvim.project').get_history_paths

Project.get_recent_projects = require('project_nvim.utils.history').get_recent_projects

---@return Project.Config.Options|nil
function Project.get_config()
    local Config = require('project_nvim.config')

    return Config.setup_called and Config.options or nil
end

return Project
