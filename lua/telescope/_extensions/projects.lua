local MODSTR = 'telescope._extensions.projects'
local ERROR = vim.log.levels.ERROR
if vim.g.project_setup ~= 1 then
    error(('(%s): `project.nvim` is not loaded!'):format(MODSTR), ERROR)
end
if not require('project.utils.util').mod_exists('telescope') then
    require('project.utils.log').error(('(%s): Telescope is not installed!'):format(MODSTR))
    error(('(%s): Telescope is not installed!'):format(MODSTR), ERROR)
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

return Projects
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
