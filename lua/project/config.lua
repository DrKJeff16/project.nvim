local Util = require('project.utils.util')
local Glob = require('project.utils.globtopattern')

local is_type = Util.is_type
local mod_exists = Util.mod_exists
local pattern_exclude = Glob.pattern_exclude

local copy = vim.deepcopy
local in_tbl = vim.tbl_contains

---@class Project.Config
---@field setup_called? boolean
local Config = {}

---Options defined after running `require('project').setup()`.
---
---@class Project.Config.Options
local DEFAULTS = {
    ---If `true` your root directory won't be changed automatically,
    ---so you have the option to manually do so using `:ProjectRoot` command.
    ------
    ---Default: `false`
    ------
    ---@type boolean
    manual_mode = false,

    ---Methods of detecting the root directory. `'lsp'` uses the native neovim
    ---LSP, while `'pattern'` uses vim-rooter like glob pattern matching. Here
    ---order matters: if one is not detected, the other is used as fallback. You
    ---can also delete or rearrange the detection methods.
    ---
    ---The detection methods get filtered and rid of duplicates during runtime.
    ------
    ---Default: `{ 'lsp' , 'pattern' }`
    ------
    ---@type ("lsp"|"pattern")[]
    detection_methods = { 'lsp', 'pattern' },

    ---All the patterns used to detect root dir, when **'pattern'** is in
    ---detection_methods.
    ---
    ---See `:h project.nvim-pattern-matching`
    ------
    ---Default: `{ '.git', '.github', '_darcs', '.hg', '.bzr', '.svn', 'Pipfile' }`
    ------
    ---@type string[]
    patterns = {
        '.git',
        '.github',
        '_darcs',
        '.hg',
        '.bzr',
        '.svn',
        'Pipfile',
    },

    ---Sets whether to use Pattern Matching rules on the LSP.
    ---
    ---If `false`, the Pattern Matching will only apply to the `pattern` detection method.
    ------
    ---Default: `true`
    ------
    ---@type boolean
    allow_patterns_for_lsp = true,

    ---Determines whether a project will be added if its project root is owned by a different user.
    ---
    ---If `false`, it won't add a project if its root is not owned by the
    ---current nvim `UID` **(UNIX only)**.
    ------
    ---Default: `true`
    ------
    ---@type boolean
    allow_different_owners = true,

    ---If enabled, set `vim.opt.autochdir` to `true`.
    ---
    ---This is disabled by default because the plugin implicitly disables `autochdir`.
    ------
    ---Default: `false`
    ------
    ---@type boolean
    enable_autochdir = false,

    ---Table of options used for the telescope picker.
    ------
    ---@class Project.Config.Options.Telescope
    telescope = {
        ---Determines whether the `telescope` picker should be called.
        ---
        ---If telescope is not installed, this doesn't make a difference.
        ---
        ---Note that even if set to `false`, you can still load the extension manually.
        ------
        ---Default: `true`
        ------
        ---@type boolean
        enabled = true,

        ---Determines whether the newest projects come first in the
        ---telescope picker (`'newest'`), or the oldest (`'oldest'`).
        ------
        ---Default: `'newest'`
        ------
        ---@type 'oldest'|'newest'
        sort = 'newest',

        ---If `true`, `telescope-file-browser.nvim` instead of builtins.
        ---
        ---If you have `telescope-file-browser.nvim` installed, you can enable this
        ---so that the Telescope picker uses it instead of the `find_files` builtin.
        ---
        ---In case it is not available, it'll fall back to `find_files`.
        ------
        ---Default: `false`
        ------
        ---@type boolean
        prefer_file_browser = false,

        ---Make hidden files visible when using the `telescope` picker.
        ------
        ---Default: `false`
        ------
        ---@type boolean
        show_hidden = false,
    },

    ---Table of lsp clients to ignore by name,
    ---e.g. `{ 'efm', ... }`.
    ---
    ---If you have `nvim-lspconfig` installed **see** `:h lspconfig-all`
    ---for a list of servers.
    ------
    ---Default: `{}`
    ------
    ---@type string[]|table
    ignore_lsp = {},

    ---Don't calculate root dir on specific directories,
    ---e.g. `{ '~/.cargo/*', ... }`.
    ---
    ---See the `Pattern Matching` section in the `README.md` for more info.
    ------
    ---Default: `{}`
    ------
    ---@type string[]|table
    exclude_dirs = {},

    ---If `false`, you'll get a _notification_ every time
    ---`project.nvim` changes directory.
    ---
    ---This is useful for debugging, or for players that
    ---enjoy verbose operations.
    ------
    ---Default: `true`
    ------
    ---@type boolean
    silent_chdir = true,

    ---Determines the scope for changing the directory.
    ---
    ---Valid options are:
    --- - `'global'`: All your nvim `cwd` will sync to your current buffer's project
    --- - `'tab'`: _Per-tab_ `cwd` sync to the current buffer's project
    --- - `'win'`: _Per-window_ `cwd` sync to the current buffer's project
    ------
    ---Default: `'global'`
    ------
    ---@type 'global'|'tab'|'win'
    scope_chdir = 'global',

    ---The path where `project.nvim` will store the project history directory,
    ---containing the project history in it.
    ---
    ---For more info, run `:lua vim.print(require('project').get_history_paths())`
    ------
    ---Default: `vim.fn.stdpath('data')`
    ------
    ---@type string
    datapath = vim.fn.stdpath('data'),
}

---Get the default options for configuring `project`.
-------
---@return Project.Config.Options
function Config.get_defaults()
    return DEFAULTS
end

---Default: `{}` (before calling `setup()`)
---
---@type table|Project.Config.Options
Config.options = {}

---@param self Project.Config
function Config:verify_scope_chdir()
    local VALID = { 'global', 'tab', 'win' }

    if is_type('string', self.options.scope_chdir) and in_tbl(VALID, self.options.scope_chdir) then
        return
    end

    self.scope_chdir = self.get_defaults().scope_chdir
end

---Ensure that the `detection_methods` option is valid.
---This includes non-repeating values, only `'lsp'` and `'pattern'` strings,
---if any.
--- ---
---@param self Project.Config
function Config:trim_methods()
    if not is_type('table', self.options.detection_methods) then
        self.options.detection_methods = self.get_defaults().detection_methods
        return
    end

    local checker = { lsp = false, pattern = false }

    ---@type ('lsp'|'pattern')[]|table
    local methods = {}

    for _, v in next, self.options.detection_methods do
        if checker.lsp and checker.pattern then
            break
        end

        if not is_type('string', v) then
            goto continue
        end

        if v == 'lsp' and not checker.lsp then
            table.insert(methods, v)
            checker.lsp = true
        end

        if v == 'pattern' and not checker.pattern then
            table.insert(methods, v)
            checker.pattern = true
        end

        ::continue::
    end

    self.options.detection_methods = copy(methods)
end

---The function called when running `require('project').setup()`.
--- ---
---@param options? Project.Config.Options
function Config.setup(options)
    options = is_type('table', options) and options or {}

    Config.options = vim.tbl_deep_extend('force', Config.get_defaults(), options)
    Config.options.exclude_dirs = vim.tbl_map(pattern_exclude, Config.options.exclude_dirs)

    Config:trim_methods()
    Config:verify_scope_chdir()

    local Path = require('project.utils.path')
    local Api = require('project.api')

    ---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/111
    vim.opt.autochdir = Config.options.enable_autochdir

    Path.init()
    Api.init()

    ---Load `projects` Telescope picker if check is `true`.
    if Config.options.telescope.enabled and mod_exists('telescope') then
        require('telescope').load_extension('projects')
    end

    Config.setup_called = true
end

return Config
