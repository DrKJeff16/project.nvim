local Util = require('project.util')

---@class Project.Extensions.Picker
---@field source Picker.Sources.Projects
local M = {}

function M.setup()
  if not Util.mod_exists('picker') then
    Util.log.error('(project.extensions.picker.setup): picker.nvim is not installed!')
    vim.notify('(project.extensions.picker.setup): picker.nvim is not installed!', vim.log.levels.ERROR)
  else
    vim.g.project_picker_loaded = 1
  end
end

local Picker = setmetatable(M, { ---@type Project.Extensions.Picker
  __index = function(self, k)
    local raw = rawget(self, k) or nil
    if raw then
      return raw
    end

    if k == 'source' then
      return Util.rawset(self, k, require('picker.sources.projects'))
    end
  end,
})

return Picker
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
