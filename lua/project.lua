local lazy = require('project.lazy')
local Config = lazy.require('project.config') ---@module 'project.config'
local Api = lazy.require('project.api') ---@module 'project.api'

---The `project` module.
--- ---
---@class Project
local Project = {}

Project.setup = Config.setup
Project.get_project_root = Api.get_project_root
Project.get_history_paths = Api.get_history_paths
Project.get_last_project = Api.get_last_project
Project.get_recent_projects = Api.get_recent_projects

---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/149
---@return string|nil
---@return string|nil
---@return string|nil
function Project.current_project()
    return Api.current_project, Api.current_method, Api.get_last_project()
end

---@return Project.Config.Options|nil
function Project.get_config()
    return Config.setup_called and Config.options or nil
end

return Project
