---@module 'project._meta'

local MODSTR = 'project'
local WARN = vim.log.levels.WARN
local ERROR = vim.log.levels.ERROR
local Config = require('project.config')
local Util = require('project.util')

---The `project.nvim` module.
--- ---
---@class Project
---@field commands Project.Commands
---@field config Project.Config
---@field core Project.Core
---@field delete_menu function
---@field delete_project fun(project: string|Project.ActionEntry, prompt?: boolean)
---@field extensions Project.Extensions
---@field get_config fun(): config: string
---@field get_history_paths Project.Core.GetHistoryPaths
---@field get_last_project Project.Core.GetLastProject
---@field get_project_root fun(bufnr?: integer): root: string|nil, method: string|nil
---@field get_recent_projects Project.Util.History.GetRecentProjects
---@field health Project.Health
---@field open_menu function
---@field popup Project.Popup
---@field recents_menu function
---@field rename_project fun(path: string, name: string): success: boolean
---@field root_files fun(scan_what?: Project.Core.ScanRoot, path?: string, prefix?: string): files_list: string[]|nil
---@field run_fzf_lua function
---@field session_menu function
---@field setup fun(options?: ProjectOpts)
---@field util Project.Util
local M = {}

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

  local Core = require('project.core')
  if refresh then
    Util.log.debug(('(%s.current_project): Refreshing current project info.'):format(MODSTR))
    return Core.get_current_project()
  end

  Util.log.debug(('(%s.current_project): Not refreshing current project info.'):format(MODSTR))
  return Core.current_project, Core.current_method, Core.last_project
end

---@param bufnr? integer
---@return string|nil root
---@nodiscard
function M.current_root(bufnr)
  Util.validate({ bufnr = { bufnr, { 'number', 'nil' }, true } })

  local root = require('project.core').get_project_root(bufnr)
  return root
end

---Removes specific root patterns from `project.nvim`'s config.
---
---Invalid values will raise a warning!
--- ---
---@param patterns string[]|string The string or list of strings containing the matching pattern(s).
function M.remove_root_patterns(patterns)
  Util.validate({ patterns = { patterns, { 'string', 'table' } } })

  local pats = Config.get().patterns
  if vim.g.project_setup ~= 1 then
    error(('(%s.remove_root_patterns): `project.nvim` is not setup!'):format(MODSTR))
  end
  if not (pats and Util.is_type('table', pats)) then
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
    return
  end

  ---@cast patterns string
  if patterns == '' then
    vim.notify(('(%s.remove_root_patterns): Skipping empty pattern: `%s`'):format(MODSTR, patterns), WARN)
    return
  end
  if not vim.list_contains(pats, patterns) then
    vim.notify(('(%s.remove_root_patterns): Skipping unavailable pattern: `%s`'):format(MODSTR, patterns), WARN)
    return
  end

  local pos = 1
  for i, pat in ipairs(pats) do
    if pat == patterns then
      pos = i
      break
    end
  end
  table.remove(pats, pos)

  Config.set('patterns', pats)
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
  local pats = Config.get().patterns
  if not (pats and Util.is_type('table', pats)) then
    Util.log.error(('(%s.add_root_patterns): Config values are unaccessible!'):format(MODSTR))
    error(('(%s.add_root_patterns): Config values are unaccessible!'):format(MODSTR))
  end

  if Util.is_type('string', patterns) then
    ---@cast patterns string
    if patterns == '' or vim.list_contains(pats, patterns) then
      Util.log.warn(('(%s.add_root_patterns): Ignoring empty or duplicate pattern: `%s`'):format(MODSTR, patterns))
      vim.notify(('(%s.add_root_patterns): Ignoring empty or duplicate pattern: `%s`'):format(MODSTR, patterns), WARN)
    else
      table.insert(pats, patterns)
      Config.set('patterns', pats)
    end
    return
  end

  ---@cast patterns string[]
  if vim.tbl_isempty(patterns) or not vim.islist(patterns) then
    Util.log.error(('(%s.add_root_patterns): Patterns table is empty or not a list!'):format(MODSTR))
    error(('(%s.add_root_patterns): Patterns table is empty or not a list!'):format(MODSTR))
  end

  for _, pat in ipairs(patterns) do
    if Util.is_type('string', pat) then
      M.add_root_patterns(pat)
    end
  end
end

local Project = setmetatable(M, { ---@type Project
  ---@param self Project
  ---@param k string|integer
  __index = function(self, k)
    if Util.mod_exists('project.' .. k) then
      return require('project.' .. k)
    end
    if k == 'delete_project' then
      return Util.history.delete_project
    end
    if k == 'get_config' then
      return Config.get_config
    end
    if k == 'get_history_paths' then
      return require('project.core').get_history_paths
    end
    if k == 'get_last_project' then
      return require('project.core').get_last_project
    end
    if k == 'get_project_root' then
      return require('project.core').get_project_root
    end
    if k == 'get_recent_projects' then
      return Util.history.get_recent_projects
    end
    if k == 'rename_project' then
      return Util.history.rename_project
    end
    if k == 'root_files' then
      return require('project.core').root_files
    end
    if k == 'run_fzf_lua' then
      return require('project.extensions')['fzf-lua'].run_fzf_lua
    end
    if k == 'setup' then
      return Config.setup
    end
    if
      vim.list_contains({ 'delete_menu', 'open_menu', 'recents_menu', 'session_menu' }, k)
      and require('project.popup')[k]
    then
      return require('project.popup')[k]
    end
    return rawget(self, k) or nil
  end,
})

return Project
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
