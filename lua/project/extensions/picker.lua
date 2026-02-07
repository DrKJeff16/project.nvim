local Util = require('project.util')
local Commands = require('project.commands')

---@class Project.Extensions.Picker
local M = {}

M.source = require('picker.sources.projects')

function M.setup()
  if not Util.mod_exists('picker') then
    vim.notify('picker.nvim is not installed!', vim.log.levels.ERROR)
    return
  end

  vim.g.project_picker_loaded = 1

  Commands.new({
    {
      name = 'ProjectPicker',
      desc = 'Open the picker.nvim picker for project.nvim',
      callback = function(ctx)
        ctx.bang = ctx.bang ~= nil and ctx.bang or false

        local cmd = { 'rg', '--files', '--ignore', '--text', '--glob', '!.git/' }
        if ctx.bang or require('project.config').options.picker.hidden then
          table.insert(cmd, '--hidden')
        end
        require('picker.sources.files').set({ cmd = cmd })
        require('picker.windows').open(M.source)
      end,
      bang = true,
    },
  })

  Commands.create_user_commands()
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
