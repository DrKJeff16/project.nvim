local Commands = require('project.commands')
local mod_exists = require('project.utils.util').mod_exists

vim.api.nvim_create_user_command('ProjectAdd', Commands.ProjectAdd, {
    bang = true,
    desc = 'Adds the current CWD project to the Project History',
})

vim.api.nvim_create_user_command('ProjectDelete', Commands.ProjectDelete, {
    desc = 'Deletes the projects given as args, assuming they are valid',
    bang = true,
    nargs = '+',

    complete = Commands.completions.ProjectDelete,
})

---`:ProjectConfig`
vim.api.nvim_create_user_command('ProjectConfig', Commands.ProjectConfig, {
    desc = 'Prints out the current configuratiion for `project.nvim`',
})

vim.api.nvim_create_user_command('ProjectRecents', Commands.ProjectRecents, {
    desc = 'Prints out the recent `project.nvim` projects',
})

vim.api.nvim_create_user_command('ProjectRoot', Commands.ProjectRoot, {
    bang = true,
    desc = 'Sets the current project root to the current CWD',
})

---Add `Fzf-Lua` command ONLY if it is installed
if mod_exists('fzf-lua') and not mod_exists('project-fzf') then
    vim.api.nvim_create_user_command('ProjectFzf', Commands.ProjectFzf, {
        desc = 'Run project.nvim through Fzf-Lua (assuming you have it installed)',
    })
end

---Add `Telescope` shortcut ONLY if it is installed and loaded
if mod_exists('telescope') then
    vim.api.nvim_create_user_command('ProjectTelescope', Commands.ProjectTelescope, {
        desc = 'Telescope shortcut for project.nvim picker',
    })
end

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
