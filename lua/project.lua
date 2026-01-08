local MODSTR = 'project'
local Api = require('project.api')
local Config = require('project.config')
local History = require('project.utils.history')
local Popup = require('project.popup')

---The `project.nvim` module.
--- ---
---@class Project
local M = {}

M.setup = Config.setup
M.get_config = Config.get_config
M.get_recent_projects = History.get_recent_projects
M.delete_project = History.delete_project
M.get_project_root = Api.get_project_root
M.get_history_paths = Api.get_history_paths
M.get_last_project = Api.get_last_project
M.open_menu = Popup.open_menu
M.delete_menu = Popup.delete_menu
M.recents_menu = Popup.recents_menu
M.session_menu = Popup.session_menu
M.run_fzf_lua = require('project.extensions.fzf-lua').run_fzf_lua

---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/149
--- ---
---@param refresh boolean|nil
---@return string|nil curr
---@return string|nil method
---@return string|nil last
function M.current_project(refresh)
  require('project.utils.util').validate({ refresh = { refresh, { 'boolean', 'nil' }, true } })
  refresh = refresh ~= nil and refresh or false

  local Log = require('project.utils.log')
  if refresh then
    Log.debug(('(%s.current_project): Refreshing current project info.'):format(MODSTR))
    return Api.get_current_project()
  end

  Log.debug(('(%s.current_project): Not refreshing current project info.'):format(MODSTR))
  return Api.current_project, Api.current_method, Api.last_project
end

local Project = setmetatable(M, { ---@type Project
  __index = M,
  __newindex = function()
    vim.notify('Project module is Read-Only!', vim.log.levels.ERROR)
  end,
})

return Project
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
