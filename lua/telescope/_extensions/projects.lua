local MODSTR = 'telescope._extensions.projects'
local ERROR = vim.log.levels.ERROR
if vim.g.project_setup ~= 1 then
    vim.notify(('(%s): `project.nvim` is not loaded!'):format(MODSTR), ERROR)
    return
end
if not require('project.utils.util').mod_exists('telescope') then
    require('project.utils.log').error(('(%s): Telescope is not installed!'):format(MODSTR))
    vim.notify(('(%s): Telescope is not installed!'):format(MODSTR), ERROR)
    return
end

local Main = require('telescope._extensions.projects.main')

---@class TelescopeProjects
---@field exports { projects: fun(opts?: table) }
---@field projects fun(opts?: table)
---@field health function
---@field setup fun(opts?: table)
local Projects = require('telescope').register_extension({
    setup = Main.setup,
    health = require('telescope._extensions.projects.healthcheck'),
    exports = { projects = Main.projects },
    projects = Main.projects,
})

return Projects
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
