-- vim:ts=2:sts=2:sw=2:et:ai:si:sta:

local config = require("project_nvim.config")
local history = require("project_nvim.utils.history")

---@class Project
---@field setup fun(options: Project.Config.Options)
---@field get_recent_projects fun(): string[]

local M = {}

M.setup = config.setup
M.get_recent_projects = history.get_recent_projects

return M
