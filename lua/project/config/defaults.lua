---@alias Project.Telescope.ActionNames
---|'browse_project_files'
---|'change_working_directory'
---|'delete_project'
---|'find_project_files'
---|'help_mappings'
---|'recent_project_files'
---|'search_in_project_files'

local in_tbl = vim.tbl_contains
local empty = vim.tbl_isempty
local WARN = vim.log.levels.WARN
local MODSTR = 'project.config.defaults'

local Util = require('project.utils.util')
local vim_has = Util.vim_has
local is_type = Util.is_type

---The options available for in `require('project').setup()`.
--- ---
---@class Project.Config.Options
---@field logging? boolean
local DEFAULTS = {
    ---If `true` your root directory won't be changed automatically,
    ---so you have the option to manually do so
    ---using the `:ProjectRoot` command.
    --- ---
    ---Default: `false`
    --- ---
    ---@type boolean
    manual_mode = false,
    ---Methods of detecting the root directory.
    ---
    --- - `'lsp'`: uses the native Neovim LSP
    ---          (see [`vim.lsp`](lua://vim.lsp))
    --- - `'pattern'`: uses `vim-rooter`-like glob pattern matching
    ---
    ---**Order matters**: if one is not detected, the other is used as fallback. You
    ---can also delete or rearrange the detection methods.
    ---
    ---Any values that aren't valid will be discarded on setup;
    ---same thing with duplicates.
    --- ---
    ---Default: `{ 'lsp' , 'pattern' }`
    --- ---
    ---@type ("lsp"|"pattern")[]
    detection_methods = { 'lsp', 'pattern' },
    ---All the patterns used to detect the project's root directory.
    ---
    ---By default it only triggers when `'pattern'` is in `detection_methods`.
    ---
    ---See `:h project.nvim-pattern-matching`.
    --- ---
    ---Default: `{ '.git', '.github', '_darcs', '.hg', '.bzr', '.svn', 'Pipfile', ... }`
    --- ---
    ---@type string[]
    patterns = {
        '.git',
        '.github',
        '_darcs',
        '.hg',
        '.bzr',
        '.svn',
        'Pipfile',
        'pyproject.toml',
        '.pre-commit-config.yaml',
        '.pre-commit-config.yml',
    },
    ---Hook to run before attaching to a new project.
    ---
    ---It recieves `target_dir` and, optionally,
    ---the `method` used to change directory.
    ---
    ---CREDITS: @danilevy1212
    --- ---
    ---Default: `function(target_dir, method) end`
    --- ---
    ---@param target_dir? string
    ---@param method? string
    before_attach = function(target_dir, method) end, ---@diagnostic disable-line:unused-local
    ---Hook to run after attaching to a new project.
    ---**_This only runs if the directory changes successfully._**
    ---
    ---It recieves `dir` and, optionally,
    ---the `method` used to change directory.
    ---
    ---CREDITS: @danilevy1212
    --- ---
    ---Default: `function(dir, method) end`
    --- ---
    ---@param dir? string
    ---@param method? string
    on_attach = function(dir, method) end, ---@diagnostic disable-line:unused-local
    ---Sets whether to use Pattern Matching rules to the LSP client.
    ---
    ---If `false` the Pattern Matching will only apply
    ---to the `'pattern'` detection method.
    ---
    ---If `true` the `patters` setting will also filter
    ---your LSP's `root_dir`, assuming there is one and `'lsp'` is in `patterns`.
    --- ---
    ---Default: `false`
    --- ---
    ---@type boolean
    allow_patterns_for_lsp = false,
    ---Determines whether a project will be added if its project root is owned by a different user.
    ---
    ---If `true`, it will add a project to the history even if its root
    ---is not owned by the current nvim `UID` **(UNIX only)**.
    --- ---
    ---Default: `false`
    --- ---
    ---@type boolean
    allow_different_owners = false,
    ---If enabled, set `vim.o.autochdir` to `true`.
    ---
    ---This is disabled by default because the plugin implicitly disables `autochdir`.
    --- ---
    ---Default: `false`
    --- ---
    ---@type boolean
    enable_autochdir = false,
    ---Make hidden files visible when using any picker.
    --- ---
    ---Default: `false`
    --- ---
    ---@type boolean
    show_hidden = false,
    ---Table of lsp clients to ignore by name,
    ---e.g. `{ 'efm', ... }`.
    ---
    ---If you have `nvim-lspconfig` installed **see** `:h lspconfig-all`
    ---for a list of servers.
    --- ---
    ---Default: `{}`
    --- ---
    ---@type string[]
    ignore_lsp = {},
    ---Don't calculate root dir on specific directories,
    ---e.g. `{ '~/.cargo/*', ... }`.
    ---
    ---See the `Pattern Matching` section in the `README.md` for more info.
    --- ---
    ---Default: `{}`
    --- ---
    ---@type string[]
    exclude_dirs = {},
    ---If `false`, you'll get a _notification_ every time
    ---`project.nvim` changes directory.
    ---
    ---This is useful for debugging, or for players that
    ---enjoy verbose operations.
    --- ---
    ---Default: `true`
    --- ---
    ---@type boolean
    silent_chdir = true,
    ---Determines the scope for changing the directory.
    ---
    ---Valid options are:
    --- - `'global'`: All your nvim `cwd` will sync to your current buffer's project
    --- - `'tab'`: _Per-tab_ `cwd` sync to the current buffer's project
    --- - `'win'`: _Per-window_ `cwd` sync to the current buffer's project
    --- ---
    ---Default: `'global'`
    --- ---
    ---@type 'global'|'tab'|'win'
    scope_chdir = 'global',
    ---Determines in what filetypes/buftypes the plugin won't execute.
    ---It's a table with two fields:
    ---
    --- - `ft`: A string array of filetypes to exclude
    --- - `bt`: A string array of buftypes to exclude
    ---
    ---CREDITS TO [@Zeioth](https://github.com/Zeioth)!:
    ---[`Zeioth/project.nvim`](https://github.com/Zeioth/project.nvim/commit/95f56b8454f3285b819340d7d769e67242d59b53)
    --- ---
    ---The default value for this one can be found in the project's `README.md`.
    --- ---
    ---@type { ft: string[], bt: string[] }
    disable_on = {
        ft = {
            '',
            'TelescopePrompt',
            'TelescopeResults',
            'alpha',
            'checkhealth',
            'lazy',
            'notify',
            'packer',
            'qf',
        }, ---`filetype`

        bt = {
            'help',
            'nofile',
            'terminal',
        }, ---`buftype`
    },
    ---The path where `project.nvim` will store the project history directory,
    ---containing the project history in it.
    ---
    ---For more info, run `:lua vim.print(require('project').get_history_paths())`
    --- ---
    ---Default: `vim.fn.stdpath('data')`
    --- ---
    ---@type string
    datapath = vim.fn.stdpath('data'),
    ---The history size. (by `@acristoffers`)
    ---
    ---This will indicate how many entries will be
    ---written to the history file.
    ---Set to `0` for no limit.
    --- ---
    ---Default: `100`
    --- ---
    ---@type integer
    historysize = 100,
}

---Plugin integrations.
--- ---
---@class Project.Config.Integrations
DEFAULTS.integrations = {}

---Integration with [folke/persistence.nvim](https://github.com/folke/persistence.nvim).
---@class Project.Config.Integrations.Persistence
DEFAULTS.integrations.persistence = {
    ---Enables integration with the plugin.
    --- ---
    ---Default: `true`
    --- ---
    ---@type boolean
    enabled = true,
    ---If enabled the integration will auto-save the current project
    ---if not found in session list.
    --- ---
    ---Default: `false`
    --- ---
    ---@type boolean
    auto_save = false,
}

---Table of options used for `fzf-lua` integration
--- ---
---@class Project.Config.FzfLua
DEFAULTS.fzf_lua = {
    ---Determines whether the `fzf-lua` integration is enabled.
    ---
    ---If `fzf-lua` is not installed, this won't make a difference.
    --- ---
    ---Default: `false`
    --- ---
    ---@type boolean
    enabled = false,
}

---Options for logging utility.
--- ---
---@class Project.Config.Logging
DEFAULTS.log = {
    ---If `true`, it enables logging in the same directory in which your
    ---history file is stored.
    --- ---
    ---Default: `false`
    --- ---
    enabled = false,
    ---The maximum logfile size (in megabytes).
    --- ---
    ---Default: `1.0`
    --- ---
    ---@type number
    max_size = 1.0,
    ---Path in which the log file will be saved.
    --- ---
    ---Default: `vim.fn.stdpath('state')`
    --- ---
    ---@type string
    logpath = vim.fn.stdpath('state'),
}

---Table of options used for the telescope picker.
--- ---
---@class Project.Config.Telescope
DEFAULTS.telescope = {
    ---Determines whether the `telescope` picker should be called
    ---from the `setup()` function.
    ---
    ---If telescope is not installed, this doesn't make a difference.
    ---
    ---Note that even if set to `false`, you can still load the extension manually.
    --- ---
    ---Default: `false`
    --- ---
    ---@type boolean
    enabled = false,
    ---Determines whether the newest projects come first in the
    ---telescope picker (`'newest'`), or the oldest (`'oldest'`).
    --- ---
    ---Default: `'newest'`
    --- ---
    ---@type 'oldest'|'newest'
    sort = 'newest',
    ---If you have `telescope-file-browser.nvim` installed, you can enable this
    ---so that the Telescope picker uses it instead of the `find_files` builtin.
    ---
    ---If `true`, use `telescope-file-browser.nvim` instead of builtins.
    ---In case it is not available, it'll fall back to `find_files`.
    --- ---
    ---Default: `false`
    --- ---
    ---@type boolean
    prefer_file_browser = false,
    ---Set this to `true` if you don't want the file picker to appear
    ---after you've selected a project.
    ---
    ---CREDITS: [UNKNOWN](https://github.com/ahmedkhalf/project.nvim/issues/157#issuecomment-2226419783)
    --- ---
    ---Default: `false`
    --- ---
    ---@type boolean
    disable_file_picker = false,
    ---Table of mappings for the Telescope picker.
    ---
    ---Only supports Normal and Insert modes.
    --- ---
    ---Default: check the README
    --- ---
    ---@type table<'n'|'i', table<string, Project.Telescope.ActionNames>>
    mappings = {
        n = {
            b = 'browse_project_files',
            d = 'delete_project',
            f = 'find_project_files',
            r = 'recent_project_files',
            s = 'search_in_project_files',
            w = 'change_working_directory',
        },
        i = {
            ['<C-b>'] = 'browse_project_files',
            ['<C-d>'] = 'delete_project',
            ['<C-f>'] = 'find_project_files',
            ['<C-r>'] = 'recent_project_files',
            ['<C-s>'] = 'search_in_project_files',
            ['<C-w>'] = 'change_working_directory',
        },
    },
}

---Checks the `historysize` option.
---
---If the option is not valid, a warning will be raised and
---the value will revert back to the default.
--- ---
---@param self Project.Config.Options
function DEFAULTS:verify_histsize()
    if vim_has('nvim-0.11') then
        vim.validate('historysize', self.historysize, 'number', false, 'integer')
    else
        vim.validate({ historysize = { self.historysize, 'number' } })
    end
    if self.historysize >= 0 or self.historysize == math.floor(self.historysize) then
        return
    end
    vim.notify('`historysize` option invalid. Reverting to default option.', WARN)
    self.historysize = DEFAULTS.historysize
end

---Checks the `scope_chdir` option.
---
---If the option is not valid, a warning will be raised and
---the value will revert back to the default.
--- ---
---@param self Project.Config.Options
function DEFAULTS:verify_scope_chdir()
    if vim_has('nvim-0.11') then
        vim.validate('scope_chdir', self.scope_chdir, 'string', false, "'global'|'tab'|'win'")
    else
        vim.validate({ scope_chdir = { self.scope_chdir, 'string' } })
    end

    local VALID = { 'global', 'tab', 'win' }
    if in_tbl(VALID, self.scope_chdir) then
        return
    end

    vim.notify('`scope_chdir` option invalid. Reverting to default option.', WARN)
    self.scope_chdir = DEFAULTS.scope_chdir
end

function DEFAULTS:verify_datapath()
    if not require('project.utils.util').dir_exists(self.datapath) then
        vim.notify('Invalid `datapath`, reverting to default.', WARN)
        self.datapath = DEFAULTS.datapath
    end
end

---Checks the `detection_methods` option.
---
---If the option is not a table, a warning will be raised and
---the option will revert back to the default.
---
---If the option is an empty table, the function will stop.
---
---The option will be stripped from any duplicates and/or
---invalid values.
--- ---
---@param self Project.Config.Options
function DEFAULTS:verify_methods()
    if not is_type('table', self.detection_methods) then
        vim.notify('`detection_methods` option is not a table. Reverting to default option.', WARN)
        self.detection_methods = DEFAULTS.detection_methods
        return
    end
    if empty(self.detection_methods) and not vim.g.project_trigger_once then
        vim.notify('`detection_methods` option is empty. `project.nvim` may not work.', WARN)
        vim.g.project_trigger_once = true
        return
    end

    ---@type ('lsp'|'pattern')[]|table
    local methods = {}
    local checker = { lsp = false, pattern = false }
    for _, v in next, self.detection_methods do
        if checker.lsp and checker.pattern then
            break
        end
        if is_type('string', v) then
            if v == 'lsp' and not checker.lsp then
                table.insert(methods, v)
                checker.lsp = true
            end
            if v == 'pattern' and not checker.pattern then
                table.insert(methods, v)
                checker.pattern = true
            end
        end
    end
    if empty(methods) and not vim.g.project_trigger_once then
        vim.notify('`detection_methods` option is empty. `project.nvim` may not work.', WARN)
        vim.g.project_trigger_once = true
        return
    end
    self.detection_methods = methods
end

---@param self Project.Config.Options
function DEFAULTS:verify_logging()
    if self.log == nil or type(self.log) ~= 'table' then
        self.log = vim.deepcopy(DEFAULTS.log)
    end
    if self.logging ~= nil and type(self.logging) == 'boolean' then
        self.log.enabled = self.logging
        self.logging = nil
        vim.notify(
            ('(%s:verify_logging): `options.logging` has migrated to `options.log.enabled`!'):format(
                MODSTR
            ),
            WARN
        )
    end

    local logpath = self.log.logpath
    if not (is_type('string', logpath) and require('project.utils.path').exists(logpath)) then
        self.log.logpath = DEFAULTS.log.logpath
    end
    local max_size = self.log.max_size
    if not (is_type('number', max_size) and max_size > 0) then
        self.log.max_size = DEFAULTS.log.max_size
    end
end

---@param self Project.Config.Options
function DEFAULTS:verify()
    self:verify_datapath()
    self:verify_histsize()
    self:verify_methods()
    self:verify_scope_chdir()
    self:verify_logging()
end

---@param opts? Project.Config.Options
---@return Project.Config.Options
function DEFAULTS.new(opts)
    if require('project.utils.util').vim_has('nvim-0.11') then
        vim.validate('opts', opts, 'table', true, 'Project.Config.Options')
    else
        vim.validate({ opts = { opts, { 'table', 'nil' } } })
    end
    opts = opts or {}

    local self = setmetatable(opts, { __index = DEFAULTS }) ---@type Project.Config.Options
    self = vim.tbl_deep_extend('keep', self, DEFAULTS)
    return self
end

return DEFAULTS
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
