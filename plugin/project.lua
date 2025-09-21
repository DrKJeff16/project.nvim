local Commands = require('project.commands')
local mod_exists = require('project.utils.util').mod_exists

---`:ProjectAdd`
vim.api.nvim_create_user_command('ProjectAdd', function(ctx)
    Commands.ProjectAdd(ctx)
end, {
    bang = Commands.ProjectAdd.bang,
    desc = Commands.ProjectAdd.desc,
})

---`:ProjectConfig`
vim.api.nvim_create_user_command('ProjectConfig', function()
    Commands.ProjectConfig()
end, {
    desc = Commands.ProjectConfig.desc,
})

---`:ProjectDelete`
vim.api.nvim_create_user_command('ProjectDelete', function(ctx)
    Commands.ProjectDelete(ctx)
end, {
    desc = Commands.ProjectDelete.desc,
    bang = Commands.ProjectDelete.bang,
    nargs = Commands.ProjectDelete.nargs,
    complete = Commands.ProjectDelete.complete,
})

---`:ProjectRecents`
vim.api.nvim_create_user_command('ProjectRecents', function()
    Commands.ProjectRecents()
end, {
    desc = Commands.ProjectRecents.desc,
})

---`:ProjectRoot`
vim.api.nvim_create_user_command('ProjectRoot', function(ctx)
    Commands.ProjectRoot(ctx)
end, {
    bang = Commands.ProjectRoot.bang,
    desc = Commands.ProjectRoot.desc,
})

---`:ProjectSession`
vim.api.nvim_create_user_command('ProjectSession', function()
    Commands.ProjectSession()
end, {
    desc = Commands.ProjectSession.desc,
})

---`:ProjectFzf`
vim.api.nvim_create_user_command('ProjectFzf', function()
    if mod_exists('fzf-lua') and not mod_exists('project-fzf') then
        ---Run `Fzf-Lua` command ONLY if it is installed
        Commands.ProjectFzf()
    end
end, {
    desc = Commands.ProjectFzf.desc,
})

---`:ProjectTelescope`
vim.api.nvim_create_user_command('ProjectTelescope', function()
    ---Run `Telescope` shortcut ONLY if it is installed and loaded
    if mod_exists('telescope') then
        Commands.ProjectTelescope()
    end
end, {
    desc = Commands.ProjectTelescope.desc,
})

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
