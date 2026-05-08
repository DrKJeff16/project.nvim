---@module 'project._meta'
---@module 'picker'

local Config = require('project.config')
local History = require('project.util.history')
local Util = require('project.util')

---@param source string[]|ProjectHistoryEntry[]
---@return ProjectPickerItem[] items
local function gen_items(source)
  local items = {} ---@type ProjectPickerItem[]
  local curr = require('project.core').get_current_project() or ''
  for i, v in ipairs(source) do
    local is_curr ---@type boolean
    if History.legacy then
      ---@cast v string
      is_curr = v == curr
    else
      ---@cast v ProjectHistoryEntry
      is_curr = v.path == curr
    end

    local n_digits, max_n_digits = Util.digits(i), Util.digits(Config.options.history.size)
    local path = ('%d. %s'):format(
      i,
      (is_curr and '*' or '') .. (' '):rep(max_n_digits - n_digits - (is_curr and 1 or 0))
    )

    if Config.options.picker.show == 'names' and not History.legacy then
      ---@cast v ProjectHistoryEntry
      path = ('%s %s'):format(path, v.name)
    else
      path = ('%s %s'):format(path, Util.strip_slash(History.legacy and v or v.path, ':p:~'))
    end
    local hl = { { 0, n_digits + 1, 'Number' } } ---@type ProjectPickerItem.Hl[]
    if is_curr then
      table.insert(hl, { n_digits + 2, n_digits + 3, 'Special' })
      table.insert(hl, { n_digits + 4, path:len(), 'String' })
    else
      table.insert(hl, { n_digits + 2, path:len(), 'String' })
    end

    table.insert(items, {
      value = Util.strip_slash(History.legacy and v or v.path),
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
  local recents = require('project').get_recent_projects()
  if Config.options.picker.sort == 'newest' then
    recents = Util.reverse(recents)
  end
  return gen_items(recents)
end

---@return table<string, fun(entry: ProjectPickerItem)> actions
function M.actions()
  return { ---@type table<string, fun(entry: ProjectPickerItem)>
    ['<C-d>'] = function(entry)
      History.delete_project(entry.value, true)
      require('picker.windows').open(M)
    end,
    ['<C-r>'] = function(entry)
      require('project.popup').rename_input(entry.value)
    end,
    ['<C-w>'] = function(entry)
      if not Util.yes_no('Change cwd to `%s`?', Util.strip_slash(entry.value, ':p:~')) then
        return
      end
      require('project.core').set_pwd(entry.value, 'picker.nvim')
    end,
  }
end

---@param entry ProjectPickerItem
function M.default_action(entry)
  if vim.fn.isdirectory(entry.value) ~= 1 then
    return
  end

  require('project.core').set_pwd(entry.value, 'picker.nvim')
  require('picker').open({ 'files' })
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
