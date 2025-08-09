---The `project_nvim` module.
--- ---
---@class Project
local Project = {}

Project.setup = require('project_nvim.config').setup
Project.get_project_root = require('project_nvim.api').get_project_root
Project.get_history_paths = require('project_nvim.api').get_history_paths
Project.get_last_project = require('project_nvim.api').get_last_project
Project.get_recent_projects = require('project_nvim.api').get_recent_projects

---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/149
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
