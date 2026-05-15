local MODSTR = 'project'
local WARN = vim.log.levels.WARN
local ERROR = vim.log.levels.ERROR
local Config = require('project.config')
local Core = require('project.core')
local Extensions = require('project.extensions')
local Popup = require('project.popup')
local Util = require('project.util')

---The `project.nvim` module.
--- ---
---@class Project
---@field commands Project.Commands
---@field config Project.Config
---@field core Project.Core
---@field extensions Project.Extensions
---@field health Project.Health
---@field popup Project.Popup
---@field util Project.Util
local M = {}

M.delete_project = Util.history.delete_project
M.get_config = Config.get_config
M.get_history_paths = Core.get_history_paths
M.get_last_project = Core.get_last_project
M.get_project_root = Core.get_project_root
M.get_recent_projects = Util.history.get_recent_projects
M.rename_project = Util.history.rename_project
M.root_files = Core.root_files
M.run_fzf_lua = Extensions['fzf-lua'].run_fzf_lua
M.setup = Config.setup

function M.delete_menu()
  Popup.delete_menu()
end

function M.open_menu()
  Popup.open_menu()
end

function M.recents_menu()
  Popup.recents_menu()
end

function M.session_menu()
  Popup.session_menu()
end

---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/149
--- ---
---@param refresh? boolean
---@return string|nil curr
---@return string|nil method
---@return string|nil last
---@nodiscard
function M.current_project(refresh)
  Util.validate({ refresh = { refresh, { 'boolean', 'nil' }, true } })
  if refresh == nil then
    refresh = false
  end

  if refresh then
    Util.log.debug(('(%s.current_project): Refreshing current project info.'):format(MODSTR))
    return Core.get_current_project()
  end

  Util.log.debug(('(%s.current_project): Not refreshing current project info.'):format(MODSTR))
  return Core.current_project, Core.current_method, Core.last_project
end

---Removes specific root patterns from `project.nvim`'s config.
---
---Invalid values will raise a warning!
--- ---
---@param patterns string[]|string The string or list of strings containing the matching pattern(s).
function M.remove_root_patterns(patterns)
  Util.validate({ patterns = { patterns, { 'string', 'table' } } })
  if vim.g.project_setup ~= 1 then
    error(('(%s.remove_root_patterns): `project.nvim` is not setup!'):format(MODSTR))
  end
  if not (Config.options and Config.options.patterns and Util.is_type('table', Config.options.patterns)) then
    error(('(%s.remove_root_patterns): Config values are unaccessible!'):format(MODSTR))
  end

  if Util.is_type('table', patterns) then
    ---@cast patterns string[]
    if vim.tbl_isempty(patterns) then
      vim.notify(('(%s.remove_root_patterns): Patterns table is empty!'):format(MODSTR), ERROR)
      return
    end
    for _, pat in ipairs(patterns) do
      if Util.is_type('string', pat) then
        M.remove_root_patterns(pat)
      end
    end
  end

  ---@cast patterns string
  if patterns == '' then
    vim.notify(('(%s.remove_root_patterns): Skipping empty pattern: `%s`'):format(MODSTR, patterns), WARN)
    return
  end
  if not vim.list_contains(Config.options.patterns, patterns) then
    vim.notify(('(%s.remove_root_patterns): Skipping unavailable pattern: `%s`'):format(MODSTR, patterns), WARN)
    return
  end

  local pos = 1
  for i, pat in ipairs(Config.options.patterns) do
    if pat == patterns then
      pos = i
      break
    end
  end
  table.remove(Config.options.patterns, pos)
end

---Add new root patterns to `project.nvim`'s config.
---
---Duplicates will be ignored.
--- ---
---@param patterns string[]|string The string or list of strings containing the new pattern(s).
function M.add_root_patterns(patterns)
  Util.validate({ patterns = { patterns, { 'string', 'table' } } })
  if vim.g.project_setup ~= 1 then
    error(('(%s.add_root_patterns): `project.nvim` is not setup!'):format(MODSTR))
  end
  if not (Config.options and Config.options.patterns and Util.is_type('table', Config.options.patterns)) then
    Util.log.error(('(%s.add_root_patterns): Config values are unaccessible!'):format(MODSTR))
    error(('(%s.add_root_patterns): Config values are unaccessible!'):format(MODSTR))
  end

  if Util.is_type('string', patterns) then
    ---@cast patterns string
    if patterns == '' or vim.list_contains(Config.options.patterns, patterns) then
      local msg = ('(%s.add_root_patterns): Ignoring empty or duplicate pattern: `%s`'):format(MODSTR, patterns)
      Util.log.warn(msg)
      vim.notify(msg, WARN)
    else
      table.insert(Config.options.patterns, patterns)
    end
    return
  end

  ---@cast patterns string[]
  if vim.tbl_isempty(patterns) then
    vim.notify(('(%s.add_root_patterns): Patterns table is empty!'):format(MODSTR), ERROR)
    Util.log.error(('(%s.add_root_patterns): Patterns table is empty!'):format(MODSTR))
    return
  end

  for _, pat in ipairs(patterns) do
    if Util.is_type('string', pat) then
      M.add_root_patterns(pat)
    end
  end
end

local Project = setmetatable(M, { ---@type Project
  __index = function(self, k)
    if Util.mod_exists('project.' .. k) then
      return require('project.' .. k)
    end
    return rawget(self, k) or nil
  end,
})

return Project
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
