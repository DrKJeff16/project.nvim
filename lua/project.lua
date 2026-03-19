local MODSTR = 'project'
local WARN = vim.log.levels.WARN
local ERROR = vim.log.levels.ERROR
local Api = require('project.api')
local Config = require('project.config')
local History = require('project.util.history')
local Popup = require('project.popup')
local Util = require('project.util')

---The `project.nvim` module.
--- ---
---@class Project
local M = {}

M.delete_menu = Popup.delete_menu
M.delete_project = History.delete_project
M.get_config = Config.get_config
M.get_history_paths = Api.get_history_paths
M.get_last_project = Api.get_last_project
M.get_project_root = Api.get_project_root
M.get_recent_projects = History.get_recent_projects
M.open_menu = Popup.open_menu
M.recents_menu = Popup.recents_menu
M.run_fzf_lua = require('project.extensions.fzf-lua').run_fzf_lua
M.session_menu = Popup.session_menu
M.setup = Config.setup

---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/149
--- ---
---@param refresh? boolean
---@return string|nil curr
---@return string|nil method
---@return string|nil last
---@nodiscard
function M.current_project(refresh)
  require('project.util').validate({ refresh = { refresh, { 'boolean', 'nil' }, true } })
  refresh = refresh ~= nil and refresh or false

  local Log = require('project.util.log')
  if refresh then
    Log.debug(('(%s.current_project): Refreshing current project info.'):format(MODSTR))
    return Api.get_current_project()
  end

  Log.debug(('(%s.current_project): Not refreshing current project info.'):format(MODSTR))
  return Api.current_project, Api.current_method, Api.last_project
end

---Removes specific root patterns from `project.nvim`'s config.
---
---Invalid values will raise a warning!
--- ---
---@param patterns string[]|string The string or list of strings containing the matching pattern(s).
function M.remove_root_patterns(patterns)
  if vim.g.project_setup ~= 1 then
    error(('(%s.remove_root_patterns): `project.nvim` is not setup!'):format(MODSTR), ERROR)
  end
  if
    not (
      Config.options
      and Config.options.patterns
      and Util.is_type('table', Config.options.patterns)
    )
  then
    error(('(%s.remove_root_patterns): Config values are unaccessible!'):format(MODSTR), ERROR)
  end

  Util.validate({ patterns = { patterns, { 'table', 'string' } } })

  if Util.is_type('string', patterns) then
    ---@cast patterns string
    if patterns == '' then
      vim.notify(
        ('(%s.remove_root_patterns): Skipping empty pattern: `%s`'):format(MODSTR, patterns),
        WARN
      )
    elseif not vim.list_contains(Config.options.patterns, patterns) then
      vim.notify(
        ('(%s.remove_root_patterns): Skipping unavailable pattern: `%s`'):format(MODSTR, patterns),
        WARN
      )
    else
      local pos = 1
      for i, pat in ipairs(Config.options.patterns) do
        if pat == patterns then
          pos = i
          break
        end
      end
      table.remove(Config.options.patterns, pos)
    end
    return
  end

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

---Add new root patterns to `project.nvim`'s config.
---
---Duplicates will be ignored.
--- ---
---@param patterns string[]|string The string or list of strings containing the new pattern(s).
function M.add_root_patterns(patterns)
  if vim.g.project_setup ~= 1 then
    error(('(%s.add_root_patterns): `project.nvim` is not setup!'):format(MODSTR), ERROR)
  end
  if
    not (
      Config.options
      and Config.options.patterns
      and Util.is_type('table', Config.options.patterns)
    )
  then
    error(('(%s.add_root_patterns): Config values are unaccessible!'):format(MODSTR), ERROR)
  end

  Util.validate({ patterns = { patterns, { 'table', 'string' } } })

  if Util.is_type('string', patterns) then
    ---@cast patterns string
    if patterns == '' or vim.list_contains(Config.options.patterns, patterns) then
      vim.notify(
        ('(%s.add_root_patterns): Ignoring empty or duplicate pattern: `%s`'):format(
          MODSTR,
          patterns
        ),
        WARN
      )
    else
      table.insert(Config.options.patterns, patterns)
    end
    return
  end

  ---@cast patterns string[]
  if vim.tbl_isempty(patterns) then
    vim.notify(('(%s.add_root_patterns): Patterns table is empty!'):format(MODSTR), ERROR)
    return
  end

  for _, pat in ipairs(patterns) do
    if Util.is_type('string', pat) then
      M.add_root_patterns(pat)
    end
  end
end

local Project = setmetatable(M, { ---@type Project
  __index = M,
  __newindex = function()
    vim.notify('Project module is Read-Only!', vim.log.levels.ERROR)
  end,
})

return Project
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
