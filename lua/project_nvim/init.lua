---@diagnostic disable:missing-fields

---@module 'project_nvim.config'

-- `project_nvim` module
---@class Project
---@field setup fun(options: table|Project.Config.Options?)
---@field get_recent_projects fun(): table|string[]
---@field get_history_paths fun(): { ['datapath']: string, ['projectpath']: string, ['historyfile']: string }
---@field get_config fun(): Project.Config.Options|nil

---@type Project
local Project = {}

---@param options? table|Project.Config.Options
function Project.setup(options)
    options = (options ~= nil and type(options) == 'table') and options or {}

    require('project_nvim.config').setup(options)
end

---@return table|string[]
function Project.get_recent_projects()
    return require('project_nvim.utils.history').get_recent_projects()
end

---@return Project.Config.Options|nil
function Project.get_config()
    local Config = require('project_nvim.config')

    return Config.setup_called and Config.options or nil
end

---@return { ['datapath']: string, ['projectpath']: string, ['historyfile']: string }
function Project.get_history_paths()
    local Path = require('project_nvim.utils.path')

    return {
        datapath = Path.datapath,
        projectpath = Path.projectpath,
        historyfile = Path.historyfile,
    }
end

return Project
