---@diagnostic disable:missing-fields

---@module 'project_nvim.config'
---@module 'project_nvim.api'

-- The `project_nvim` module
---@class Project
-- Calls setup for the plugin
---@field setup fun(options: table|Project.Config.Options?)
---@field get_recent_projects fun(): table|string[]
---@field get_history_paths fun(path: ('datapath'|'projectpath'|'historyfile')?): string|HistoryPaths
-- CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/149
---@field current_project fun(): string|nil,string|nil,string|nil
---@field get_config fun(): Project.Config.Options|nil
---@field get_project_root fun(): (string?,string?)
---@field get_last_project fun(): last: string|nil
local Project = {}

Project.setup = require('project_nvim.config').setup

-- CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/112
Project.get_project_root = require('project_nvim.api').get_project_root

Project.get_history_paths = require('project_nvim.api').get_history_paths

Project.get_last_project = require('project_nvim.api').get_last_project

Project.get_recent_projects = require('project_nvim.utils.history').get_recent_projects

-- CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/149
---@return string|nil
---@return string|nil
---@return string|nil
function Project.current_project()
    local Api = require('project_nvim.api')

    return Api.current_project, Api.current_method, Api.get_last_project()
end

---@return Project.Config.Options|nil
function Project.get_config()
    local Config = require('project_nvim.config')

    return Config.setup_called and Config.options or nil
end

return Project
