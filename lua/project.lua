local lazy = require('project.lazy')
local Config = lazy.require('project.config') ---@module 'project.config'
local Api = lazy.require('project.api') ---@module 'project.api'

---The `project` module.
--- ---
---@class Project
local Project = {}

---@param options? Project.Config.Options
function Project.setup(options)
    Config.setup(options)
end

---@return string|nil root
---@return string|nil method
function Project.get_project_root()
    local root, method = Api.get_project_root()
    return root, method
end

---@return string|{ datapath: string, projectpath: string, historyfile: string }
function Project.get_history_paths()
    return Api.get_history_paths()
end

---@return string|nil
function Project.get_last_project()
    return Api.get_last_project()
end

---@return string[] recent
function Project.get_recent_projects()
    local recent = Api.get_recent_projects()
    return recent
end

---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/149
---@return string|nil curr
---@return string|nil method
---@return string|nil last
function Project.current_project()
    local curr, method, last = Api.get_current_project()

    return curr, method, last
end

---@return Project.Config.Options|nil
function Project.get_config()
    return Config.setup_called and Config.options or nil
end

return Project
