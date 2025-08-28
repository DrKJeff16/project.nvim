local Config = require('project.config')
local Api = require('project.api')
local Util = require('project.utils.util')

local is_type = Util.is_type

---The `project` module.
--- ---
---@class Project
local Project = {}

---@param options? Project.Config.Options
function Project.setup(options)
    Config.setup(options)
end

---Returns the project root, as well as the method used.
--- ---
---@return string|nil root
---@return string|nil method
function Project.get_project_root()
    local root, method = Api.get_project_root()
    return root, method
end

---@param project string|Project.ActionEntry
function Project.delete_project(project)
    Api.delete_project(project)
end

---@param path? 'datapath'|'projectpath'|'historyfile'
---@return string|{ datapath: string, projectpath: string, historyfile: string }
function Project.get_history_paths(path)
    return Api.get_history_paths(path)
end

---@param refresh? boolean
---@return string|nil last
function Project.get_last_project(refresh)
    refresh = is_type('boolean', refresh) and refresh or false
    local last = refresh and Api.last_project or Api.get_last_project()

    return last
end

---@return string[] recent
function Project.get_recent_projects()
    local recent = Api.get_recent_projects()
    return recent
end

---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/149
--- ---
---@param refresh? boolean
---@return string|nil curr
---@return string|nil method
---@return string|nil last
function Project.current_project(refresh)
    refresh = is_type('boolean', refresh) and refresh or false

    local curr, method, last = Api.current_project, Api.current_method, Api.last_project

    if refresh then
        curr, method, last = Api.get_current_project()
    end

    return curr, method, last
end

---@return Project.Config.Options|nil
function Project.get_config()
    return Config.setup_called and Config.options or nil
end

return Project

---vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
