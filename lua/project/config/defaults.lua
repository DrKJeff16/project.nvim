---@alias Project.Telescope.ActionNames
---|'browse_project_files'
---|'change_working_directory'
---|'delete_project'
---|'find_project_files'
---|'help_mappings'
---|'recent_project_files'
---|'search_in_project_files'

local MODSTR = 'project.config.defaults'
local WARN = vim.log.levels.WARN
local in_list = vim.tbl_contains
local empty = vim.tbl_isempty
local Util = require('project.utils.util')

---The options available for in `require('project').setup()`.
--- ---
---@class Project.Config.Options
local DEFAULTS = {
    ---If `true` your root directory won't be changed automatically,
    ---so you have the option to manually do so
    ---using the `:ProjectRoot` command.
    --- ---
    ---Default: `false`
    --- ---
    manual_mode = false, ---@type boolean
    ---Methods of detecting the root directory.
    ---
    --- - `'pattern'`: uses `vim-rooter`-like glob pattern matching
    --- - `'lsp'`: uses the native Neovim LSP (**CAN CAUSE BUGGY BEHAVIOUR**)
    ---
    ---**Order matters**: if one is not detected, the other is used as fallback. You
    ---can also delete or rearrange the detection methods.
    ---
    ---Any values that aren't valid will be discarded on setup;
    ---same thing with duplicates.
    --- ---
    ---Default: `{ 'pattern' }`
    --- ---
    detection_methods = { 'pattern' }, ---@type ('lsp'|'pattern')[]
    ---All the patterns used to detect the project's root directory.
    ---
    ---By default it only triggers when `'pattern'` is in `detection_methods`.
    ---
    ---See `:h project.nvim-pattern-matching`.
    --- ---
    ---Default: `{ '.git', '.github', '_darcs', '.hg', '.bzr', '.svn', 'Pipfile', ... }`
    --- ---
    patterns = { ---@type string[]
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
    ---@param target_dir string
    ---@param method string
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
    ---@param dir string
    ---@param method string
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
    allow_patterns_for_lsp = false, ---@type boolean
    ---Determines whether a project will be added if its project root is owned by a different user.
    ---
    ---If `true`, it will add a project to the history even if its root
    ---is not owned by the current nvim `UID` **(UNIX only)**.
    --- ---
    ---Default: `false`
    --- ---
    allow_different_owners = false, ---@type boolean
    ---If enabled, set `vim.o.autochdir` to `true`.
    ---
    ---This is disabled by default because the plugin implicitly disables `autochdir`.
    --- ---
    ---Default: `false`
    --- ---
    enable_autochdir = false, ---@type boolean
    ---Make hidden files visible when using any picker.
    --- ---
    ---Default: `false`
    --- ---
    show_hidden = false, ---@type boolean
    ---Table of lsp clients to ignore by name,
    ---e.g. `{ 'efm', ... }`.
    ---
    ---If you have `nvim-lspconfig` installed **see** `:h lspconfig-all`
    ---for a list of servers.
    --- ---
    ---Default: `{}`
    --- ---
    ignore_lsp = {}, ---@type string[]
    ---Don't calculate root dir on specific directories,
    ---e.g. `{ '~/.cargo/*', ... }`.
    ---
    ---For more info see `:h project-nvim.pattern-matching`.
    --- ---
    ---Default: `{}`
    --- ---
    exclude_dirs = {}, ---@type string[]
    ---If `false`, you'll get a _notification_ every time
    ---`project.nvim` changes directory.
    ---
    ---This is useful for debugging, or for players that
    ---enjoy verbose operations.
    --- ---
    ---Default: `true`
    --- ---
    silent_chdir = true, ---@type boolean
    ---Determines the scope for changing the directory.
    ---
    ---Valid options are:
    --- - `'global'`: All your nvim `cwd` will sync to your current buffer's project
    --- - `'tab'`: _Per-tab_ `cwd` sync to the current buffer's project
    --- - `'win'`: _Per-window_ `cwd` sync to the current buffer's project
    --- ---
    ---Default: `'global'`
    --- ---
    scope_chdir = 'global', ---@type 'global'|'tab'|'win'
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
    disable_on = { ---@type { ft: string[], bt: string[] }
        ---`filetype`
        ft = {
            '',
            'log',
            'TelescopePrompt',
            'TelescopeResults',
            'alpha',
            'checkhealth',
            'lazy',
            'notify',
            'packer',
            'qf',
        },
        ---`buftype`
        bt = {
            'help',
            'nofile',
            'terminal',
        },
    },
    ---The path where `project.nvim` will store the project history directory,
    ---containing the project history in it.
    ---
    ---For more info, run `:lua vim.print(require('project').get_history_paths())`
    --- ---
    ---Default: `vim.fn.stdpath('data')`
    --- ---
    datapath = vim.fn.stdpath('data'), ---@type string
    ---The history size. (by `@acristoffers`)
    ---
    ---This will indicate how many entries will be
    ---written to the history file.
    ---Set to `0` for no limit.
    --- ---
    ---Default: `100`
    --- ---
    historysize = 100, ---@type integer
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
    enabled = false, ---@type boolean
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
    enabled = false, ---@type boolean
    ---The maximum logfile size (in megabytes).
    --- ---
    ---Default: `1.1`
    --- ---
    max_size = 1.1, ---@type number
    ---Path in which the log file will be saved.
    --- ---
    ---Default: `vim.fn.stdpath('state')`
    --- ---
    logpath = vim.fn.stdpath('state'), ---@type string
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
    enabled = false, ---@type boolean
    ---Determines whether the newest projects come first in the
    ---telescope picker (`'newest'`), or the oldest (`'oldest'`).
    --- ---
    ---Default: `'newest'`
    --- ---
    sort = 'newest', ---@type 'oldest'|'newest'
    ---If you have `telescope-file-browser.nvim` installed, you can enable this
    ---so that the Telescope picker uses it instead of the `find_files` builtin.
    ---
    ---If `true`, use `telescope-file-browser.nvim` instead of builtins.
    ---In case it is not available, it'll fall back to `find_files`.
    --- ---
    ---Default: `false`
    --- ---
    prefer_file_browser = false, ---@type boolean
    ---Set this to `true` if you don't want the file picker to appear
    ---after you've selected a project.
    ---
    ---CREDITS: [UNKNOWN](https://github.com/ahmedkhalf/project.nvim/issues/157#issuecomment-2226419783)
    --- ---
    ---Default: `false`
    --- ---
    disable_file_picker = false, ---@type boolean
    ---Table of mappings for the Telescope picker.
    ---
    ---Only supports Normal and Insert modes.
    --- ---
    ---Default: check the README
    --- ---
    mappings = { ---@type table<'n'|'i', table<string, Project.Telescope.ActionNames>>
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
function DEFAULTS:verify_histsize()
    if Util.vim_has('nvim-0.11') then
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
function DEFAULTS:verify_scope_chdir()
    if Util.vim_has('nvim-0.11') then
        vim.validate('scope_chdir', self.scope_chdir, 'string', false, "'global'|'tab'|'win'")
    else
        vim.validate({ scope_chdir = { self.scope_chdir, 'string' } })
    end

    local VALID = { 'global', 'tab', 'win' }
    if in_list(VALID, self.scope_chdir) then
        return
    end

    vim.notify(
        ('`scope_chdir` option invalid (`%s`). Reverting to default option.'):format(
            self.scope_chdir
        ),
        WARN
    )
    self.scope_chdir = DEFAULTS.scope_chdir
end

function DEFAULTS:verify_datapath()
    if not require('project.utils.util').dir_exists(self.datapath) then
        vim.notify(('Invalid datapath `%s`, reverting to default.'):format(self.datapath), WARN)
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
function DEFAULTS:verify_methods()
    if not Util.is_type('table', self.detection_methods) then
        vim.notify('`detection_methods` option is not a table. Reverting to default option.', WARN)
        self.detection_methods = DEFAULTS.detection_methods
        return
    end
    if empty(self.detection_methods) then
        vim.notify('`detection_methods` option is empty. `project.nvim` may not work.', WARN)
        return
    end
    local lsp_warning = [[
WARNING (project.nvim): Using the `lsp` method has been the cause of some
annoying bugs (see https://github.com/DrKJeff16/project.nvim/issues/24 for more details).

If you don't want this warning to pop up just set `vim.g.project_lsp_nowarn = 1`
in your config **before calling `setup()`**.
Otherwise you can just not include the `lsp` method it in your `setup()`
(`detection_methods = { 'pattern' }`).

I apologize for the inconvenience, I'm trying to fix this bug.
    ]]

    local methods = {} ---@type ('lsp'|'pattern')[]
    local checker = { lsp = false, pattern = false }
    local warning = function() end
    for _, v in ipairs(self.detection_methods) do
        if checker.lsp and checker.pattern then
            break
        end
        if Util.is_type('string', v) then
            if v == 'lsp' and not checker.lsp then
                if vim.g.project_lsp_nowarn ~= 1 then
                    warning = vim.schedule_wrap(function()
                        vim.api.nvim_echo({ { lsp_warning, 'WarningMsg' } }, true, { err = true })
                    end)
                end
                table.insert(methods, v)
                checker.lsp = true
            end
            if v == 'pattern' and not checker.pattern then
                table.insert(methods, v)
                checker.pattern = true
            end
        end
    end
    if empty(methods) then
        vim.notify('`detection_methods` table is empty! `project.nvim` may not work!', WARN)
    end
    self.detection_methods = methods
    warning()
end

function DEFAULTS:verify_logging()
    if self.log == nil or type(self.log) ~= 'table' then
        self.log = vim.deepcopy(DEFAULTS.log)
    end
    if self.logging ~= nil and type(self.logging) == 'boolean' then
        self.log.enabled = self.logging
        self.logging = nil
        vim.notify(
            ('`options.logging` is deprecated, use `options.log.enabled`!'):format(MODSTR),
            WARN
        )
    end

    local logpath = self.log.logpath
    if not (Util.is_type('string', logpath) and require('project.utils.path').exists(logpath)) then
        self.log.logpath = DEFAULTS.log.logpath
    end
    local max_size = self.log.max_size
    if not (Util.is_type('number', max_size) and max_size > 0) then
        self.log.max_size = DEFAULTS.log.max_size
    end
end

function DEFAULTS:expand_excluded()
    if vim.tbl_isempty(self.exclude_dirs) then
        return
    end

    for i, v in ipairs(self.exclude_dirs) do
        self.exclude_dirs[i] = Util.rstrip('/', vim.fn.fnamemodify(v, ':p'))
    end
end

function DEFAULTS:verify()
    self:verify_datapath()
    self:verify_histsize()
    self:verify_methods()
    self:verify_scope_chdir()
    self:verify_logging()
end

---@param opts? Project.Config.Options
---@return Project.Config.Options
function DEFAULTS:new(opts)
    if require('project.utils.util').vim_has('nvim-0.11') then
        vim.validate('opts', opts, 'table', true, 'Project.Config.Options')
    else
        vim.validate({ opts = { opts, { 'table', 'nil' } } })
    end
    opts = opts or {}

    self.__index = self
    self.__newindex = function(t, k, v)
        rawset(t, k, v)
    end
    local obj = setmetatable(opts, self) ---@type Project.Config.Options
    return obj
end

return DEFAULTS
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
