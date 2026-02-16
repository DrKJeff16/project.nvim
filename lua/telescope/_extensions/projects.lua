local MODSTR = 'telescope._extensions.projects'
local ERROR = vim.log.levels.ERROR
if vim.g.project_setup ~= 1 then
  error('project.nvim` is not loaded!', ERROR)
end
if not require('project.util').mod_exists('telescope') then
  require('project.util.log').error(('(%s): Telescope is not installed!'):format(MODSTR))
  error('Telescope is not installed!', ERROR)
end

local setup = require('telescope._extensions.projects.main').setup
local projects = require('telescope._extensions.projects.main').projects

---@class TelescopeProjects
---@field exports { projects: fun(opts?: table) }
---@field projects fun(opts?: table)
---@field health function
---@field setup fun(opts?: table)
local Projects = require('telescope').register_extension({
  setup = setup,
  health = require('telescope._extensions.projects.healthcheck'),
  exports = { projects = projects },
  projects = projects,
})

require('project.commands').new({
  {
    name = 'ProjectTelescope',
    desc = 'Telescope shortcut for `projects` picker',
    nargs = '*',
    callback = function(ctx)
      Projects.projects(ctx.fargs)
    end,
  },
})

return Projects
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
