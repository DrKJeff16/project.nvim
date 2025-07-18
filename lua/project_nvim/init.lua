---@diagnostic disable:missing-fields

---@module 'project_nvim.config'
---@module 'project_nvim.api'

-- `project_nvim` module
---@class Project
---@field setup fun(options: table|Project.Config.Options?)
---@field get_recent_projects fun(): table|string[]
---@field get_history_paths fun(path: ('datapath'|'projectpath'|'historyfile')?): string|HistoryPaths
-- CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/149
---@field current_project fun(): string|nil
---@field get_config fun(): Project.Config.Options|nil
---@field get_project_root fun(): (string?,string?)

---@type Project
local Project = {}

Project.setup = require('project_nvim.config').setup

-- CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/112
Project.get_project_root = require('project_nvim.api').get_project_root

Project.get_history_paths = require('project_nvim.api').get_history_paths

-- CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/149
Project.current_project = function()
    return require('project_nvim.api').current_project
end

Project.get_recent_projects = require('project_nvim.utils.history').get_recent_projects

---@return Project.Config.Options|nil
function Project.get_config()
    local Config = require('project_nvim.config')

    return Config.setup_called and Config.options or nil
end

return Project
