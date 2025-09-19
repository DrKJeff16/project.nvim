local Commands = require('project.commands')
local mod_exists = require('project.utils.util').mod_exists

vim.api.nvim_create_user_command('ProjectAdd', function(ctx)
    Commands.ProjectAdd(ctx)
end, {
    bang = true,
    desc = Commands.ProjectAdd.desc,
})

vim.api.nvim_create_user_command('ProjectDelete', function(ctx)
    Commands.ProjectDelete(ctx)
end, {
    desc = Commands.ProjectDelete.desc,
    bang = true,
    nargs = '+',

    complete = Commands.ProjectDelete.complete,
})

---`:ProjectConfig`
vim.api.nvim_create_user_command('ProjectConfig', function()
    Commands.ProjectConfig()
end, {
    desc = Commands.ProjectConfig.desc,
})

vim.api.nvim_create_user_command('ProjectRecents', function()
    Commands.ProjectRecents()
end, {
    desc = Commands.ProjectRecents.desc,
})

vim.api.nvim_create_user_command('ProjectRoot', function(ctx)
    Commands.ProjectRoot(ctx)
end, {
    bang = true,
    desc = Commands.ProjectRoot.desc,
})

vim.api.nvim_create_user_command('ProjectSession', function()
    Commands.ProjectSession()
end, {
    desc = Commands.ProjectSession.desc,
})

---Add `Fzf-Lua` command ONLY if it is installed
if mod_exists('fzf-lua') and not mod_exists('project-fzf') then
    vim.api.nvim_create_user_command('ProjectFzf', function()
        Commands.ProjectFzf()
    end, {
        desc = Commands.ProjectFzf.desc,
    })
end

---Add `Telescope` shortcut ONLY if it is installed and loaded
if mod_exists('telescope') then
    vim.api.nvim_create_user_command('ProjectTelescope', function()
        Commands.ProjectTelescope()
    end, {
        desc = Commands.ProjectTelescope.desc,
    })
end

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
