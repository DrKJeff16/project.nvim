---@class Project.Extensions
---@field ['fzf-lua'] Project.Extensions.FzfLua
---@field picker Project.Extensions.Picker
---@field snacks Project.Extensions.Snacks
local M = setmetatable({}, {
  __index = function(_, k)
    if require('project.util').mod_exists('project.extensions.' .. k) then
      return require('project.extensions.' .. k)
    end
  end,
})

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
