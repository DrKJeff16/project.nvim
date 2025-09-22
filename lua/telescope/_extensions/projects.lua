local Log = require('project.utils.log')
local MODSTR = 'telescope._extensions.projects'

if not require('project.utils.util').mod_exists('telescope') then
    Log.error(('(%s): Telescope is not installed!'):format(MODSTR))
    error(('(%s): Telescope is not installed!'):format(MODSTR))
end

local Main = require('telescope._extensions.projects.main')
local Telescope = require('telescope')

Log.debug(('(%s): Registering `projects` picker...'):format(MODSTR))

---@class TelescopeProjects
---@field exports { projects: fun(opts?: table) }
---@field projects fun(opts?: table)
---@field setup fun(opts?: table)
local M = Telescope.register_extension({
    setup = Main.setup,
    exports = { projects = Main.projects },
    projects = Main.projects,
})

Log.debug(('(%s): Registering `projects` picker successfully!'):format(MODSTR))
return M

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
