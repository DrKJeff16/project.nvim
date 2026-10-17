local Util = require('project.util')

---@generic T: table, F
---@param t T
---@param k any
---@param fallback F
---@return F fallback
local function get(t, k, fallback)
  return Util.get(t, k, function()
    return Util.rawset(t, k, fallback)
  end, true)
end

---@class Project.Extensions.Picker
---@field source Picker.Sources.Projects
local M = {}

setmetatable(M, {
  __index = function(self, k)
    local raw = Util.get(self, k)
    if raw then
      return raw
    end

    if type(k) ~= 'string' then
      return
    end

    if k == 'source' then
      return get(self, k, require('picker.sources.projects'))
    end
  end,
})

function M.setup()
  if not Util.mod_exists('picker', true) then
    Util.log.notify_error('(project.extensions.picker.setup): picker.nvim is not installed!')
  else
    vim.g.project_picker_loaded = 1
  end
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
