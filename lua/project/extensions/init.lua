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

---@class Project.Extensions
---@field ['fzf-lua'] Project.Extensions.FzfLua
---@field picker Project.Extensions.Picker
---@field snacks Project.Extensions.Snacks
local M = {}

setmetatable(M, {
  __index = function(self, k) ---@param self Project.Extensions
    local raw = Util.get(self, k)
    if raw ~= nil then
      return raw
    end

    if type(k) ~= 'string' then
      return
    end

    if Util.mod_exists('project.extensions.' .. k, true) then
      return get(self, k, require('project.extensions.' .. k))
    end
  end,
})

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
