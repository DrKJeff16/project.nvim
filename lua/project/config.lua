local MODSTR = 'project.config'
local ERROR = vim.log.levels.ERROR
local in_list = vim.list_contains

---@class Project.Config
---@field conf_loc? { win: integer, bufnr: integer }
local Config = {}

---Get the default options for configuring `project`.
--- ---
---@return Project.Config.Options
function Config.get_defaults()
    return require('project.config.defaults')
end

---@type Project.Config.Options
Config.options = setmetatable({}, { __index = Config.get_defaults() })

---The function called when running `require('project').setup()`.
--- ---
---@param options? Project.Config.Options the `project.nvim` config options
function Config.setup(options)
    local Util = require('project.utils.util')
    if Util.vim_has('nvim-0.11') then
        vim.validate('options', options, 'table', true)
    else
        vim.validate({ options = { options, { 'table', 'nil' } } })
    end
    options = options or {}
    local pattern_exclude = require('project.utils.globtopattern').pattern_exclude
    Config.options = Config.get_defaults():new(options)
    Config.options:expand_excluded()
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
    if Config.options.telescope.enabled and Util.mod_exists('telescope') then
        require('telescope').load_extension('projects')
        Log.info(('(%s.setup): Telescope Picker initialized.'):format(MODSTR))
    end

    if vim.g.project_setup ~= 1 then
        vim.g.project_setup = 1
        Log.debug(('(%s.setup): `g:project_setup` set to `1`.'):format(MODSTR))
    end
    require('project.commands').create_user_commands()
end

---@return string|nil
function Config.get_config()
    if vim.g.project_setup ~= 1 then
        local Log = require('project.utils.log')
        Log.error(('(%s.get_config): `project.nvim` is not set up!'):format(MODSTR))
        error(('(%s.get_config): `project.nvim` is not set up!'):format(MODSTR), ERROR)
    end
    local exceptions = {
        'new',
        'verify_datapath',
        'verify_histsize',
        'verify_logging',
        'verify_methods',
        'verify_scope_chdir',
    }
    local opts = {} ---@type Project.Config.Options
    for k, v in pairs(Config.options) do
        if not in_list(exceptions, k) then
            opts[k] = v
        end
    end
    return vim.inspect(opts)
end

function Config.open_win()
    if Config.conf_loc ~= nil then
        return
    end

    Config.conf_loc = {}
    Config.conf_loc.bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(
        Config.conf_loc.bufnr,
        0,
        -1,
        true,
        vim.split(Config.get_config(), '\n', { plain = true, trimempty = true })
    )
    local height = math.floor(vim.o.lines * 0.75)
    local width = math.floor(vim.o.columns * 0.8)
    Config.conf_loc.win = vim.api.nvim_open_win(Config.conf_loc.bufnr, true, {
        focusable = true,
        noautocmd = true,
        relative = 'editor',
        row = math.floor((vim.o.lines - height) / 2) - 1,
        col = math.floor((vim.o.columns - width) / 2) - 1,
        style = 'minimal',
        title = 'Project Config',
        title_pos = 'center',
        width = width,
        height = height,
        border = 'single',
        zindex = 40,
    })

    vim.wo[Config.conf_loc.win].signcolumn = 'no'
    vim.wo[Config.conf_loc.win].list = false
    vim.wo[Config.conf_loc.win].number = false
    vim.wo[Config.conf_loc.win].wrap = false
    vim.wo[Config.conf_loc.win].colorcolumn = ''

    vim.bo[Config.conf_loc.bufnr].filetype = ''
    vim.bo[Config.conf_loc.bufnr].fileencoding = 'utf-8'
    vim.bo[Config.conf_loc.bufnr].buftype = 'nowrite'
    vim.bo[Config.conf_loc.bufnr].modifiable = false

    vim.keymap.set('n', 'q', Config.close_win, {
        buffer = Config.conf_loc.bufnr,
        noremap = true,
        silent = true,
    })
end

function Config.close_win()
    if not Config.conf_loc then
        return
    end

    vim.api.nvim_buf_delete(Config.conf_loc.bufnr, { force = true })
    pcall(vim.api.nvim_win_close, Config.conf_loc.win, true)

    Config.conf_loc = nil
end

return Config
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
