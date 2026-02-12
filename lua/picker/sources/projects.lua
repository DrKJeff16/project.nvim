local Util = require('project.util')
local Config = require('project.config')

---@param source string[]
---@return PickerItem[] items
local function gen_items(source)
  local items = {} ---@type PickerItem[]
  local curr = require('project.api').get_current_project() or ''
  for i, v in ipairs(source) do
    local is_curr = v == curr
    local n_digits, max_n_digits = Util.digits(i), Util.digits(Config.options.historysize)
    local path = ('%d. %s %s'):format(
      i,
      (is_curr and '*' or '') .. (' '):rep(max_n_digits - n_digits - (is_curr and 1 or 0)),
      vim.fn.fnamemodify(v, ':~')
    )
    local hl = { { 0, n_digits + 1, 'Number' } } ---@type { [1]: integer, [2]: integer, [3]: string }[]
    if is_curr then
      table.insert(hl, { n_digits + 2, n_digits + 3, 'Special' })
      table.insert(hl, { n_digits + 4, path:len(), 'String' })
    else
      table.insert(hl, { n_digits + 2, path:len(), 'String' })
    end
    table.insert(items, {
      value = v,
      str = path,
      highlight = hl,
    })
  end
  return items
end

---@class Picker.Sources.Projects
local M = {}

function M.get()
  local recents = require('project').get_recent_projects()
  if Config.options.picker.sort == 'newest' then
    recents = Util.reverse(recents)
  end
  return gen_items(recents)
end

---@return table<string, fun(entry: PickerItem)>
function M.actions()
  return { ---@type table<string, fun(entry: PickerItem)>
    ['<C-d>'] = function(entry)
      if
        vim.fn.confirm(
          ('Delete project? (`%s`)'):format(vim.fn.fnamemodify(entry.value, ':~')),
          '&Yes\n&No',
          2
        ) == 1
      then
        require('project.util.history').delete_project(entry.value)
      end
      require('picker.windows').open(M)
    end,
    ['<C-w>'] = function(entry)
      if
        vim.fn.confirm(
          ('Change cwd to `%s`?'):format(vim.fn.fnamemodify(entry.value, ':~')),
          '&Yes\n&No',
          2
        ) ~= 1
      then
        require('project.api').set_pwd(entry.value, 'picker.nvim')
      end
      require('picker.windows').open(M)
    end,
  }
end

---@param entry PickerItem
function M.default_action(entry)
  if vim.fn.isdirectory(entry.value) == 1 then
    require('project.api').set_pwd(entry.value, 'picker.nvim')
    local files = vim.deepcopy(require('picker.sources.files'))
    files.preview_win = false
    require('picker').open({ 'files' })
  end
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
