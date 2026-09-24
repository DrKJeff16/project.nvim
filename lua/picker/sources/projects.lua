---@module 'picker'
---@module 'project'

local Project = require('project')

---@param source ProjectHistoryEntry[]
---@return ProjectPickerItem[] items
---@nodiscard
local function gen_items(source)
  local curr = Project.core.get_current() or ''
  local items = {} ---@type ProjectPickerItem[]
  for i, v in ipairs(source) do
    local n_digits, max_n_digits = Project.util.digits(i), Project.util.digits(Project.config.get().history.size)
    local path = ('%d. %s'):format(
      i,
      (v.path == curr and '*' or '') .. (' '):rep(max_n_digits - n_digits - (v.path == curr and 1 or 0))
    )
    path = ('%s %s'):format(
      path,
      Project.config.get().picker.show == 'names' and v.name or Project.util.strip_slash(v.path, ':p:~')
    )
    local hl = { { 0, n_digits + 1, 'Number' } } ---@type ProjectPickerItem.Hl[]
    if v.path == curr then
      table.insert(hl, { n_digits + 2, n_digits + 3, 'Special' })
      table.insert(hl, { n_digits + 4, path:len(), 'String' })
    else
      table.insert(hl, { n_digits + 2, path:len(), 'String' })
    end
    table.insert(items, { highlight = hl, str = path, value = Project.util.strip_slash(v.path) })
  end
  return items
end

---@class Picker.Sources.Projects
local M = {}

---@return ProjectPickerItem[] items
function M.get()
  local recents = Project.get_recent_projects()
  return gen_items(Project.config.get().picker.sort == 'newest' and Project.util.reverse(recents) or recents)
end

---@return table<string, fun(entry: ProjectPickerItem)> actions
function M.actions()
  return { ---@type table<string, fun(entry: ProjectPickerItem)>
    ['<C-d>'] = function(entry)
      Project.util.history.delete_project(entry.value, true)
      vim.cmd.Picker({ args = { 'projects' } })
    end,
    ['<C-r>'] = function(entry)
      Project.popup.rename_input(entry.value)
    end,
    ['<C-w>'] = function(entry)
      if Project.util.yes_no('Change cwd to `%s`?', Project.util.strip_slash(entry.value, ':p:~')) then
        Project.core.set_pwd(entry.value, 'picker.nvim')
      end
    end,
  }
end

---@param entry ProjectPickerItem
function M.default_action(entry)
  if vim.fn.isdirectory(entry.value) == 1 and Project.core.set_pwd(entry.value, 'picker.nvim') then
    require('picker').open({ 'files' })
  end
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
