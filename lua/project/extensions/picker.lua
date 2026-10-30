---@generic T: table, F
---@param t T
---@param k any
---@param fallback F
---@return F fallback
local function get(t, k, fallback)
  local Util = require('project.util')
  return Util.get(t, k, function()
    return Util.rawset(t, k, fallback)
  end, true)
end

---@class Project.Extensions.Picker
---@field source Picker.Sources.Projects
local M = {}

setmetatable(M, {
  __index = function(self, k)
    local Util = require('project.util')
    local raw = Util.get(self, k)
    if raw ~= nil then
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
  assert(require('project.util').mod_exists('picker', true), 'picker.nvim is not installed')
  vim.g.project_picker_loaded = 1
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
