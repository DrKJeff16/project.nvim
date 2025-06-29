---@diagnostic disable:missing-fields

-- `project_nvim` module
---@class Project
---@field setup fun(options: table|Project.Config.Options?)
---@field get_recent_projects fun(): table|string[]

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

return Project
