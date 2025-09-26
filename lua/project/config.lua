local MODSTR = 'project.config'
local Util = require('project.utils.util')
local Glob = require('project.utils.globtopattern')
local mod_exists = Util.mod_exists
local pattern_exclude = Glob.pattern_exclude

---@class Project.Config
local Config = {}

---Get the default options for configuring `project`.
--- ---
---@return Project.Config.Options
function Config.get_defaults()
    return require('project.config.defaults')
end

---Default: `{}` (before calling `setup()`).
--- ---
---@type Project.Config.Options
Config.options = {}

---The function called when running `require('project').setup()`.
--- ---
---@param options? Project.Config.Options
function Config.setup(options)
    if Util.vim_has('nvim-0.11') then
        vim.validate('options', options, 'table', true, 'Project.Config.Options')
    else
        vim.validate({ options = { options, { 'table', 'nil' } } })
    end
    options = options or {}

    Config.options = Config.get_defaults().new(options)
    Config.options.exclude_dirs = vim.tbl_map(pattern_exclude, Config.options.exclude_dirs)
    Config.options:verify() -- Verify config integrity

    ---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/111
    vim.o.autochdir = Config.options.enable_autochdir

    require('project.utils.path').init()
    require('project.api').init()
    local Log = require('project.utils.log')
    if Config.options.log.enabled then
        Log.init()
    end
    if Config.options.telescope.enabled and mod_exists('telescope') then
        require('telescope').load_extension('projects')
        Log.info(('(%s.setup): Telescope Picker initialized.'):format(MODSTR))
    end

    vim.g.project_setup = 1
    Log.debug(('(%s.setup): `g:project_setup` set to `1`.'):format(MODSTR))
    require('project.commands').create_user_commands()
end

return Config
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
