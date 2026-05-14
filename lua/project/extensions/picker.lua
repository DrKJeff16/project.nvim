local MODSTR = 'project.extensions.picker'
local Log = require('project.util.log')
local Util = require('project.util')

---@class Project.Extensions.Picker
local M = {}

M.source = require('picker.sources.projects')

function M.setup()
  if not Util.mod_exists('picker') then
    Log.error(('(%s.setup): picker.nvim is not installed!'):format(MODSTR))
    vim.notify(('(%s.setup): picker.nvim is not installed!'):format(MODSTR), vim.log.levels.ERROR)
    return
  end

  vim.g.project_picker_loaded = 1
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
