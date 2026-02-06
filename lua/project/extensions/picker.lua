local Util = require('project.util')
local Commands = require('project.commands')
local Config = require('project.config')

---@class Project.Extensions.Picker
local M = {}

---@param source string[]
---@return PickerItem[] items
local function gen_items(source)
  local items = {} ---@type PickerItem[]
  for i, v in ipairs(source) do
    table.insert(items, {
      value = v,
      str = ('%d. %s'):format(i, vim.fn.fnamemodify(v, ':~')),
      highlight = {
        { 0, 2, 'Special' },
      },
    })
  end
  return items
end

M.source = {
  get = function()
    local recents = require('project').get_recent_projects()
    if Config.options.picker.sort == 'newest' then
      recents = Util.reverse(recents)
    end
    return gen_items(recents)
  end,
  actions = function()
    return {
      ['<C-d>'] = function(entry) ---@param entry PickerItem
        require('project.util.history').delete_project(entry.value)
      end,
    }
  end,
  default_action = function(entry)
    if vim.fn.isdirectory(entry.value) == 1 then
      require('project.api').set_pwd(entry.value, 'picker.nvim')
      local files = vim.deepcopy(require('picker.sources.files'))
      files.preview_win = false
      require('picker.windows').open(files, {})
    end
  end,
}

function M.setup()
  if not Util.mod_exists('picker') then
    error('picker.nvim is not installed!', vim.log.levels.ERROR)
  end

  Commands.new({
    {
      name = 'ProjectPicker',
      desc = 'Open the picker.nvim picker for project.nvim',
      callback = function()
        require('picker.windows').open(M.source, {})
      end,
    },
  })

  Commands.create_user_commands()
end

return M
