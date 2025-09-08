local Main = require('telescope._extensions.projects.main')
local Telescope = require('telescope')

---@class TelescopeProjects
---@field exports { projects: fun(opts?: table) }
---@field projects fun(opts?: table)
---@field setup fun(opts: table)

---@type TelescopeProjects
local M = Telescope.register_extension({
    setup = Main.setup,
    exports = { projects = Main.projects },
    projects = Main.projects,
})

return M

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
