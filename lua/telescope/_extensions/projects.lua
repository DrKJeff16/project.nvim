local Util = require('project.utils.util')
local mod_exists = Util.mod_exists

if not mod_exists('telescope') then
    return
end

local Telescope = require('telescope')
local Main = require('telescope._extensions.projects.main')

local setup = Main.setup
local projects = Main.projects

return Telescope.register_extension({
    setup = setup,
    exports = { projects = projects },
    projects = projects,
})

---vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
