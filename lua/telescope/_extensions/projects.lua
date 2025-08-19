local Util = require('project.utils.util')
local mod_exists = Util.mod_exists

if not mod_exists('telescope') then
    return
end

local Telescope = require('telescope')
local Main = require('telescope._extensions.projects.main')

return Telescope.register_extension({
    setup = Main.setup,
    exports = { projects = Main.projects },
    projects = Main.projects,
})
