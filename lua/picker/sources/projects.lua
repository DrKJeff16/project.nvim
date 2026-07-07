---@module 'project._meta'
---@module 'picker'

local Project = require('project')

---@param source ProjectHistoryEntry[]
---@return ProjectPickerItem[] items
local function gen_items(source)
  local items = {} ---@type ProjectPickerItem[]
  local curr = Project.core.get_current_project() or ''
  for i, v in ipairs(source) do
    local is_curr = v.path == curr
    local n_digits, max_n_digits = Project.util.digits(i), Project.util.digits(Project.config.get().history.size)
    local path = ('%d. %s'):format(
      i,
      (is_curr and '*' or '') .. (' '):rep(max_n_digits - n_digits - (is_curr and 1 or 0))
    )

    if Project.config.get().picker.show == 'names' then
      path = ('%s %s'):format(path, v.name)
    else
      path = ('%s %s'):format(path, Project.util.strip_slash(v.path, ':p:~'))
    end
    local hl = { { 0, n_digits + 1, 'Number' } } ---@type ProjectPickerItem.Hl[]
    if is_curr then
      table.insert(hl, { n_digits + 2, n_digits + 3, 'Special' })
      table.insert(hl, { n_digits + 4, path:len(), 'String' })
    else
      table.insert(hl, { n_digits + 2, path:len(), 'String' })
    end

    table.insert(items, {
      value = Project.util.strip_slash(v.path),
      str = path,
      highlight = hl,
    })
  end
  return items
end

---@class Picker.Sources.Projects
local M = {}

---@return ProjectPickerItem[] items
function M.get()
  local recents = Project.get_recent_projects()
  if Project.config.get().picker.sort == 'newest' then
    recents = Project.util.reverse(recents)
  end
  return gen_items(recents)
end

---@return table<string, fun(entry: ProjectPickerItem)> actions
function M.actions()
  return { ---@type table<string, fun(entry: ProjectPickerItem)>
    ['<C-d>'] = function(entry)
      Project.util.history.delete_project(entry.value, true)
      vim.cmd.Picker('projects')
    end,
    ['<C-r>'] = function(entry)
      Project.popup.rename_input(entry.value)
    end,
    ['<C-w>'] = function(entry)
      if not Project.util.yes_no('Change cwd to `%s`?', Project.util.strip_slash(entry.value, ':p:~')) then
        return
      end
      Project.core.set_pwd(entry.value, 'picker.nvim')
    end,
  }
end

---@param entry ProjectPickerItem
function M.default_action(entry)
  if vim.fn.isdirectory(entry.value) ~= 1 then
    return
  end

  Project.core.set_pwd(entry.value, 'picker.nvim')
  require('picker').open({ 'files' })
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
