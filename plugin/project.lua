local Commands = require('project.commands')
local mod_exists = require('project.utils.util').mod_exists

vim.api.nvim_create_user_command('ProjectAdd', function(ctx)
    Commands.ProjectAdd(ctx)
end, {
    bang = true,
    desc = 'Adds the current CWD project to the Project History',
})

vim.api.nvim_create_user_command('ProjectDelete', function(ctx)
    Commands.ProjectDelete(ctx)
end, {
    desc = 'Deletes the projects given as args, assuming they are valid',
    bang = true,
    nargs = '+',

    complete = Commands.ProjectDelete.complete,
})

---`:ProjectConfig`
vim.api.nvim_create_user_command('ProjectConfig', function()
    Commands.ProjectConfig()
end, {
    desc = 'Prints out the current configuratiion for `project.nvim`',
})

vim.api.nvim_create_user_command('ProjectRecents', function()
    Commands.ProjectRecents()
end, {
    desc = 'Prints out the recent `project.nvim` projects',
})

vim.api.nvim_create_user_command('ProjectRoot', function(ctx)
    Commands.ProjectRoot(ctx)
end, {
    bang = true,
    desc = 'Sets the current project root to the current CWD',
})

vim.api.nvim_create_user_command('ProjectSession', function()
    Commands.ProjectSession()
end, {
    desc = 'Prints out the current `project.nvim` projects session',
})

---Add `Fzf-Lua` command ONLY if it is installed
if mod_exists('fzf-lua') and not mod_exists('project-fzf') then
    vim.api.nvim_create_user_command('ProjectFzf', function()
        Commands.ProjectFzf()
    end, {
        desc = 'Run project.nvim through Fzf-Lua (assuming you have it installed)',
    })
end

---Add `Telescope` shortcut ONLY if it is installed and loaded
if mod_exists('telescope') then
    vim.api.nvim_create_user_command('ProjectTelescope', function()
        Commands.ProjectTelescope()
    end, {
        desc = 'Telescope shortcut for project.nvim picker',
    })
end

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
