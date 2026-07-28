---@class Project.Extensions.Picker
local M = {}

M.source = require('picker.sources.projects')

function M.setup()
  if not require('project.util').mod_exists('picker') then
    require('project.util.log').error('(project.extensions.picker.setup): picker.nvim is not installed!')
    vim.notify('(project.extensions.picker.setup): picker.nvim is not installed!', vim.log.levels.ERROR)
    return
  end

  vim.g.project_picker_loaded = 1
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
