assert(vim.g.project_setup == 1, 'project.nvim` is not loaded')
assert(require('project.util').mod_exists('telescope'), 'Telescope is not loaded')

---@class TelescopeProjects
---@field exports { projects: fun(opts?: table) }
---@field health function
---@field projects fun(opts?: table)
---@field setup fun(opts?: table)

return require('telescope').register_extension({
  exports = { projects = require('telescope._extensions.projects.main').projects },
  health = require('telescope._extensions.projects.healthcheck'),
  projects = require('telescope._extensions.projects.main').projects,
  setup = require('telescope._extensions.projects.main').setup,
}) --[[@as TelescopeProjects]]
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
