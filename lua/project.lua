---The `project` module.
--- ---
---@class Project
local Project = {}

Project.setup = require('project.config').setup
Project.get_project_root = require('project.api').get_project_root
Project.get_history_paths = require('project.api').get_history_paths
Project.get_last_project = require('project.api').get_last_project
Project.get_recent_projects = require('project.api').get_recent_projects

---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/149
---@return string|nil
---@return string|nil
---@return string|nil
function Project.current_project()
    local Api = require('project.api')

    return Api.current_project, Api.current_method, Api.get_last_project()
end

---@return Project.Config.Options|nil
function Project.get_config()
    local Config = require('project.config')

    return Config.setup_called and Config.options or nil
end

return Project
