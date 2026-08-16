if vim.g.project_setup ~= 1 then
  vim.notify('project.nvim` is not loaded!', vim.log.levels.ERORR)
  return
end
if not require('project.util').mod_exists('telescope.init') then
  require('project').util.log.error('(telescope._extensions.projects): Telescope is not installed!')
  vim.notify('Telescope is not installed!', vim.log.levels.ERROR)
  return
end

local projects = require('telescope._extensions.projects.main').projects

---@class TelescopeProjects
---@field exports { projects: fun(opts?: table) }
---@field projects fun(opts?: table)
---@field health function
---@field setup fun(opts?: table)
local M = require('telescope').register_extension({
  exports = { projects = projects },
  health = require('telescope._extensions.projects.healthcheck'),
  projects = projects,
  setup = require('telescope._extensions.projects.main').setup,
})

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
