---@diagnostic disable:lowercase-global

rockspec_format = '3.1'

package = 'project.nvim'
version = 'scm-1'

source = {
    url = 'git://github.com/DrKJeff16/project.nvim',
}

description = {
    detailed = [[
        A Neovim plugin written in Lua that, under configurable conditions, automatically sets
        the user's cwd to the current project root and provides project management.
    ]],
    homepage = 'https://github.com/DrKJeff16/project.nvim',
    license = 'Apache-2.0',
    labels = { "neovim", "neovim-plugin" },
}
dependencies = {
    'lua==5.1',
}
build = {
    type = 'builtin',
    modules = {
        project = 'lua/project.lua',
        ['project.api'] = 'lua/project/api.lua',
        ['project.commands'] = 'lua/project/commands.lua',
        ['project.config'] = 'lua/project/config.lua',
        ['project.config.defaults'] = 'lua/project/config/defaults.lua',
        ['project.extensions.fzf-lua'] = 'lua/project/extensions/fzf-lua.lua',
        ['project.health'] = 'lua/project/health.lua',
        ['project.popup'] = 'lua/project/popup.lua',
        ['project.utils.globtopattern'] = 'lua/project/utils/globtopattern.lua',
        ['project.utils.history'] = 'lua/project/utils/history.lua',
        ['project.utils.log'] = 'lua/project/utils/log.lua',
        ['project.utils.path'] = 'lua/project/utils/path.lua',
        ['project.utils.util'] = 'lua/project/utils/util.lua',
        ['telescope._extensions.projects'] = 'lua/telescope/_extensions/projects.lua',
        ['telescope._extensions.projects.actions'] = 'lua/telescope/_extensions/projects/actions.lua',
        ['telescope._extensions.projects.main'] = 'lua/telescope/_extensions/projects/main.lua',
        ['telescope._extensions.projects.util'] = 'lua/telescope/_extensions/projects/util.lua',
    },
    copy_directories = {
        'doc',
    },
}
