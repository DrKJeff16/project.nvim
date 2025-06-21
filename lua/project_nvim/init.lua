---@diagnostic disable:missing-fields

---@class Project
---@field setup fun(options: table|Project.Config.Options)
---@field get_recent_projects fun(): table|string[]

---@type Project
local Project = {}

Project.setup = require('project_nvim.config').setup
Project.get_recent_projects = require('project_nvim.utils.history').get_recent_projects

return Project
