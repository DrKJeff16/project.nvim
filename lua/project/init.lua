---@module 'project._meta'

local Util = require('project.util')

---@generic T: table, F
---@param t T
---@param k any
---@param fallback F
---@return F fallback
local function get(t, k, fallback)
  return Util.get(t, k, function()
    return Util.rawset(t, k, fallback)
  end, true)
end

---The `project.nvim` module.
--- ---
---@class Project
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
---@field util Project.Util
local M = {}

setmetatable(M, {
  __index = function(self, k) ---@param self Project
    local raw = Util.get(self, k)
    if raw ~= nil then
      return raw
    end

    if type(k) ~= 'string' then
      return
    end

    ---@cast k string
    if Util.mod_exists('project.' .. k, true) then
      return get(self, k, require('project.' .. k))
    end
    if k == 'delete_project' then
      return get(self, k, self.util.history.delete_project)
    end
    if k == 'get_config' then
      return get(self, k, self.config.get_config)
    end
    if k == 'get_history_paths' then
      return get(self, k, self.core.get_history_paths)
    end
    if k == 'get_last_project' then
      return get(self, k, self.core.get_last)
    end
    if k == 'get_project_root' then
      return get(self, k, self.core.get_project_root)
    end
    if k == 'get_recent_projects' then
      return get(self, k, self.util.history.get_recent_projects)
    end
    if k == 'rename_project' then
      return get(self, k, self.util.history.rename_project)
    end
    if k == 'root_files' then
      return get(self, k, self.core.root_files)
    end
    if k == 'run_fzf_lua' then
      return get(self, k, self.extensions['fzf-lua'].run)
    end
    if self.popup[k] then
      return get(self, k, self.popup[k])
    end
  end,
})

M.setup = M.config.setup

---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/149
--- ---
---@param refresh? boolean
---@return string|nil|? curr
---@return string|nil|? method
---@return string|nil|? last
---@nodiscard
function M.current_project(refresh)
  M.util.validate({ refresh = { refresh, { 'boolean', 'nil' }, true } })
  if refresh == nil then
    refresh = false
  end

  if refresh then
    M.util.log.debug('(project.current_project): Refreshing current project info.')
    return M.core.get_current()
  end

  M.util.log.debug('(project.current_project): Not refreshing current project info.')
  return M.core.get_current_project(), M.core.get_current_method(), M.core.get_last_project()
end

---@param bufnr? integer
---@return string|nil|? root
---@nodiscard
function M.current_root(bufnr)
  M.util.validate({ bufnr = { bufnr, { 'number', 'nil' }, true } })

  return (M.core.get_project_root(bufnr))
end

---Removes specific root patterns from `project.nvim`'s config.
---
---Invalid values will raise a warning!
--- ---
---@param patterns string[]|string The string or list of strings containing the matching pattern(s).
function M.remove_root_patterns(patterns)
  M.util.validate({ patterns = { patterns, { 'string', 'table' } } })

  local pats = M.config.get().patterns
  if vim.g.project_setup ~= 1 then
    M.util.log.error('(project.remove_root_patterns): `project.nvim` is not setup!')
    error('(project.remove_root_patterns): `project.nvim` is not setup!')
  end
  if not pats or type(pats) ~= 'table' then
    M.util.log.error('(project.remove_root_patterns): Config values are unaccessible!')
    error('(project.remove_root_patterns): Config values are unaccessible!')
  end

  if type(patterns) == 'table' then
    if #patterns == 0 then
      M.util.log.notify_error('(project.remove_root_patterns): Patterns table is empty!')
    else
      for _, pat in ipairs(patterns) do
        if type(pat) == 'string' then
          M.remove_root_patterns(pat)
        end
      end
    end
  elseif patterns == '' then
    M.util.log.notify_warn(('(project.remove_root_patterns): Skipping empty pattern: `%s`'):format(patterns))
  elseif not vim.list_contains(pats, patterns) then
    M.util.log.notify_warn(('(project.remove_root_patterns): Skipping unavailable pattern: `%s`'):format(patterns))
  else
    local pos = 1
    for i, pat in ipairs(pats) do
      if pat == patterns then
        pos = i
        break
      end
    end
    table.remove(pats, pos)

    M.config.set('patterns', pats)
  end
end

---Add new root patterns to `project.nvim`'s config.
---
---Duplicates will be ignored.
--- ---
---@param patterns string[]|string The string or list of strings containing the new pattern(s).
function M.add_root_patterns(patterns)
  M.util.validate({ patterns = { patterns, { 'string', 'table' } } })
  if vim.g.project_setup ~= 1 then
    M.util.log.error('(project.add_root_patterns): `project.nvim` is not setup!')
    error('(project.add_root_patterns): `project.nvim` is not setup!')
  end

  local pats = M.config.get().patterns
  if not pats or type(pats) ~= 'table' then
    M.util.log.error('(project.add_root_patterns): Config values are unaccessible!')
    error('(project.add_root_patterns): Config values are unaccessible!')
  end

  if type(patterns) == 'string' then
    if patterns == '' or vim.list_contains(pats, patterns) then
      M.util.log.notify_warn(
        ('(project.add_root_patterns): Ignoring empty or duplicate pattern: `%s`'):format(patterns)
      )
    else
      table.insert(pats, patterns)
      M.config.set('patterns', pats)
    end
  elseif not #patterns > 0 and vim.islist(patterns) then
    for _, pat in ipairs(patterns) do
      if type(pat) == 'string' then
        M.add_root_patterns(pat)
      end
    end
  else
    M.util.log.notify_error('(project.add_root_patterns): Patterns table is empty or not a list!')
  end
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
