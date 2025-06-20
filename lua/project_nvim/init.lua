---@diagnostic disable:missing-fields

local config = require('project_nvim.config')
local history = require('project_nvim.utils.history')

---@class Project
---@field setup fun(options: table|Project.Config.Options)
---@field get_recent_projects fun(): table|string[]

---@type Project
local Project = {}

Project.setup = config.setup
Project.get_recent_projects = history.get_recent_projects

return Project
