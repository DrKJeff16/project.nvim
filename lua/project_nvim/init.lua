---@diagnostic disable:missing-fields

local config = require('project_nvim.config')
local globpattern = require('project_nvim.utils.globpattern')
local history = require('project_nvim.utils.history')
local path = require('project_nvim.utils.path')

---@class Project.Utils
---@field globpattern Project.Utils.GlobPattern
---@field history Project.Utils.History
---@field path Project.Utils.Path

---@class Project
---@field config Project.Config
---@field utils Project.Utils
---@field setup fun(options: Project.Config.Options)
---@field get_recent_projects fun(): string[]

---@type Project
local M = {}

M.setup = config.setup
M.get_recent_projects = history.get_recent_projects

M.config = config

M.utils = {}
M.utils.history = history
M.utils.path = path
M.utils.globpattern = globpattern

return M
