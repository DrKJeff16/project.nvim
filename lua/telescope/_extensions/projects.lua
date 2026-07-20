if vim.g.project_setup ~= 1 then
  error('project.nvim` is not loaded!')
end
if not require('project.util').mod_exists('telescope') then
  require('project').util.log.error('(telescope._extensions.projects): Telescope is not installed!')
  error('Telescope is not installed!')
end

local projects = require('telescope._extensions.projects.main').projects

---@class TelescopeProjects
---@field exports { projects: fun(opts?: table) }
---@field projects fun(opts?: table)
---@field health function
---@field setup fun(opts?: table)
local M = require('telescope').register_extension({
  setup = require('telescope._extensions.projects.main').setup,
  health = require('telescope._extensions.projects.healthcheck'),
  exports = { projects = projects },
  projects = projects,
})

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
