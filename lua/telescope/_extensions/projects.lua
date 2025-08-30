if not vim.g.project_setup then
    return
end

local Main = require('telescope._extensions.projects.main')
local Telescope = require('telescope')

local setup = Main.setup
local projects = Main.projects

return Telescope.register_extension({
    setup = setup,
    exports = { projects = projects },
    projects = projects,
})

---vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
