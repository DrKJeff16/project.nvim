---@module 'project._meta'

local WARN = vim.log.levels.WARN

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
---@field get_project_root fun(bufnr?: integer): root: string|nil|?, method: string|nil|?
---@field get_recent_projects Project.Util.History.GetRecentProjects
---@field health Project.Health
---@field open_menu function
---@field popup Project.Popup
---@field recents_menu function
---@field rename_project fun(path: string, name: string): success: boolean
---@field root_files fun(scan_what?: Project.Core.ScanRoot, path?: string, prefix?: string): files_list: string[]|nil|?
---@field run_fzf_lua function
---@field session_menu function
---@field setup fun(options?: ProjectOpts)
---@field util Project.Util
local M = {}

---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/149
--- ---
---@param refresh? boolean
---@return string|nil|? curr
---@return string|nil|? method
---@return string|nil|? last
---@nodiscard
function M.current_project(refresh)
  local Util = require('project.util')
  Util.validate({ refresh = { refresh, { 'boolean', 'nil' }, true } })
  if refresh == nil then
    refresh = false
  end

  local Core = require('project.core')
  if refresh then
    Util.log.debug('(project.current_project): Refreshing current project info.')
    return Core.get_current_project()
  end

  Util.log.debug('(project.current_project): Not refreshing current project info.')
  return Core.current_project, Core.current_method, Core.last_project
end

---@param bufnr? integer
---@return string|nil|? root
---@nodiscard
function M.current_root(bufnr)
  require('project.util').validate({ bufnr = { bufnr, { 'number', 'nil' }, true } })

  local root = require('project.core').get_project_root(bufnr)
  return root
end

---Removes specific root patterns from `project.nvim`'s config.
---
---Invalid values will raise a warning!
--- ---
---@param patterns string[]|string The string or list of strings containing the matching pattern(s).
function M.remove_root_patterns(patterns)
  local Util = require('project.util')
  Util.validate({ patterns = { patterns, { 'string', 'table' } } })

  local Config = require('project.config')
  local pats = Config.get().patterns
  if vim.g.project_setup ~= 1 then
    Util.log.error('(project.remove_root_patterns): `project.nvim` is not setup!')
    error('(project.remove_root_patterns): `project.nvim` is not setup!')
  end
  if not (pats and Util.is_type('table', pats)) then
    Util.log.error('(project.remove_root_patterns): Config values are unaccessible!')
    error('(project.remove_root_patterns): Config values are unaccessible!')
  end

  if Util.is_type('table', patterns) then
    ---@cast patterns string[]
    if vim.tbl_isempty(patterns) then
      Util.log.error('(project.remove_root_patterns): Patterns table is empty!')
      vim.notify('(project.remove_root_patterns): Patterns table is empty!', vim.log.levels.ERROR)
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
    Util.log.warn(('(project.remove_root_patterns): Skipping empty pattern: `%s`'):format(patterns))
    vim.notify(('(project.remove_root_patterns): Skipping empty pattern: `%s`'):format(patterns), WARN)
    return
  end
  if not vim.list_contains(pats, patterns) then
    Util.log.warn(('(project.remove_root_patterns): Skipping unavailable pattern: `%s`'):format(patterns))
    vim.notify(('(project.remove_root_patterns): Skipping unavailable pattern: `%s`'):format(patterns), WARN)
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
  local Util = require('project.util')
  Util.validate({ patterns = { patterns, { 'string', 'table' } } })
  if vim.g.project_setup ~= 1 then
    Util.log.error('(project.add_root_patterns): `project.nvim` is not setup!')
    error('(project.add_root_patterns): `project.nvim` is not setup!')
  end

  local Config = require('project.config')
  local pats = Config.get().patterns
  if not (pats and Util.is_type('table', pats)) then
    Util.log.error('(project.add_root_patterns): Config values are unaccessible!')
    error('(project.add_root_patterns): Config values are unaccessible!')
  end

  if Util.is_type('string', patterns) then
    ---@cast patterns string
    if patterns == '' or vim.list_contains(pats, patterns) then
      Util.log.warn(('(project.add_root_patterns): Ignoring empty or duplicate pattern: `%s`'):format(patterns))
      vim.notify(('(project.add_root_patterns): Ignoring empty or duplicate pattern: `%s`'):format(patterns), WARN)
    else
      table.insert(pats, patterns)
      Config.set('patterns', pats)
    end
    return
  end

  ---@cast patterns string[]
  if vim.tbl_isempty(patterns) or not vim.islist(patterns) then
    Util.log.error('(project.add_root_patterns): Patterns table is empty or not a list!')
    error('(project.add_root_patterns): Patterns table is empty or not a list!')
  end

  for _, pat in ipairs(patterns) do
    if Util.is_type('string', pat) then
      M.add_root_patterns(pat)
    end
  end
end

local Project = setmetatable(M, { ---@type Project
  __index = function(self, k)
    if require('project.util').mod_exists('project.' .. k) then
      return require('project.' .. k)
    end
    if k == 'delete_project' then
      return require('project.util').history.delete_project
    end
    if k == 'get_config' then
      return require('project.config').get_config
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
      return require('project.util').history.get_recent_projects
    end
    if k == 'rename_project' then
      return require('project.util').history.rename_project
    end
    if k == 'root_files' then
      return require('project.core').root_files
    end
    if k == 'run_fzf_lua' then
      return require('project.extensions')['fzf-lua'].run_fzf_lua
    end
    if k == 'setup' then
      return require('project.config').setup
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
