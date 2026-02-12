local Util = require('project.util')
local Config = require('project.config')

---@class ProjectPickerItem.Hl
---@field [1] integer
---@field [2] integer
---@field [3] string

---@class ProjectPickerItem: PickerItem
---@field value string
---@field highlight? ProjectPickerItem.Hl[]

---@param source string[]
---@return ProjectPickerItem[] items
local function gen_items(source)
  local items = {} ---@type ProjectPickerItem[]
  local curr = require('project.api').get_current_project() or ''
  for i, v in ipairs(source) do
    local is_curr = v == curr
    local n_digits, max_n_digits = Util.digits(i), Util.digits(Config.options.historysize)
    local path = ('%d. %s %s'):format(
      i,
      (is_curr and '*' or '') .. (' '):rep(max_n_digits - n_digits - (is_curr and 1 or 0)),
      vim.fn.fnamemodify(v, ':~')
    )
    local hl = { { 0, n_digits + 1, 'Number' } } ---@type ProjectPickerItem.Hl[]
    if is_curr then
      table.insert(hl, { n_digits + 2, n_digits + 3, 'Special' })
      table.insert(hl, { n_digits + 4, path:len(), 'String' })
    else
      table.insert(hl, { n_digits + 2, path:len(), 'String' })
    end

    local item = { value = v, str = path, highlight = hl } ---@type ProjectPickerItem
    table.insert(items, item)
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
      require('project.util.history').delete_project(entry.value, true)
      require('picker.windows').open(M)
    end,
    ['<C-w>'] = function(entry)
      if not Util.yes_no('Change cwd to `%s`?', vim.fn.fnamemodify(entry.value, ':~')) then
        return
      end
      require('project.api').set_pwd(entry.value, 'picker.nvim')
    end,
  }
end

---@param entry ProjectPickerItem
function M.default_action(entry)
  if vim.fn.isdirectory(entry.value) ~= 1 then
    return
  end

  require('project.api').set_pwd(entry.value, 'picker.nvim')
  require('picker').open({ 'files' })
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
