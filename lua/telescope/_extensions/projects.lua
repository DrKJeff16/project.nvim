local Main = require('telescope._extensions.projects.main')
local Telescope = require('telescope')

return Telescope.register_extension({
    setup = Main.setup,
    exports = { projects = Main.projects },
    projects = Main.projects,
})

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
