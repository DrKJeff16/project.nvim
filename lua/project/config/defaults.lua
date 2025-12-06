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
local Util = require('project.utils.util')

---The options available for in `require('project').setup()`.
--- ---
---@class Project.Config.Options
---@field detection_methods? ('lsp'|'pattern')[]
local DEFAULTS = {
    ---If `true` then LSP-based method detection
    ---will take precedence over traditional pattern matching.
    ---
    ---See |project-nvim.pattern-matching| for more info.
    --- ---
    ---Default: `true`
    --- ---
    use_lsp = true, ---@type boolean
    ---If `true` your root directory won't be changed automatically,
    ---so you have the option to manually do so
    ---using the `:ProjectRoot` command.
    --- ---
    ---Default: `false`
    --- ---
    manual_mode = false, ---@type boolean
    ---All the patterns used to detect the project's root directory.
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
        '.csproj',
        '.sln',
        '.nvim.lua',
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
    ---to normal pattern matching.
    ---
    ---If `true` the `patterns` setting will also filter
    ---your LSP's `root_dir`, assuming there is one
    ---and `use_lsp` is set to `true`.
    --- ---
    ---Default: `false`
    --- ---
    allow_patterns_for_lsp = false, ---@type boolean
    ---Determines whether a project will be added
    ---if its project root is owned by a different user.
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
        ft = { -- `filetype`
            '',
            'NvimTree',
            'TelescopePrompt',
            'TelescopeResults',
            'alpha',
            'checkhealth',
            'lazy',
            'log',
            'ministarter',
            'neo-tree',
            'notify',
            'nvim-pack',
            'packer',
            'qf',
        },
        bt = { 'help', 'nofile', 'nowrite', 'terminal' }, -- `buftype`
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
    vim.validate('historysize', self.historysize, { 'number', 'nil' }, true, 'integer')

    if not self.historysize or type(self.historysize) ~= 'number' then
        self.historysize = DEFAULTS.historysize
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
    vim.validate('scope_chdir', self.scope_chdir, { 'string', 'nil' }, true, "'global'|'tab'|'win'")

    if self.scope_chdir and in_list({ 'global', 'tab', 'win' }, self.scope_chdir) then
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
    if not (self.datapath and require('project.utils.util').dir_exists(self.datapath)) then
        vim.notify(('Invalid datapath `%s`, reverting to default.'):format(self.datapath), WARN)
        self.datapath = DEFAULTS.datapath
    end
end

---@return { [1]: 'pattern' }|{ [1]: 'lsp', [2]: 'pattern' } methods
function DEFAULTS:gen_methods()
    local methods = { 'pattern' } ---@type { [1]: 'pattern' }|{ [1]: 'lsp', [2]: 'pattern' }
    if self.use_lsp then
        table.insert(methods, 1, 'lsp')
    end

    return setmetatable(methods, {
        __index = methods,
        __newindex = function(_, _, _)
            vim.notify('Detection methods are immutable!', vim.log.levels.ERROR)
        end,
    })
end

function DEFAULTS:verify_logging()
    local Path = require('project.utils.path')
    local log = self.log
    if not log or type(log) ~= 'table' then
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

    if not (Util.is_type('string', log.logpath) and Path.exists(log.logpath)) then
        self.log.logpath = DEFAULTS.log.logpath
    end
    if not (Util.is_type('number', log.max_size) and log.max_size > 0) then
        self.log.max_size = DEFAULTS.log.max_size
    end
end

function DEFAULTS:expand_excluded()
    if not self.exclude_dirs or type(self.exclude_dirs) ~= 'table' then
        self.exclude_dirs = {}
    end
    if vim.tbl_isempty(self.exclude_dirs) then
        return
    end

    for i, v in ipairs(self.exclude_dirs) do
        self.exclude_dirs[i] = Util.rstrip('\\', Util.rstrip('/', vim.fn.fnamemodify(v, ':p')))
    end
end

---Verify config integrity.
--- ---
function DEFAULTS:verify()
    self:verify_datapath()
    self:verify_histsize()
    self:verify_scope_chdir()
    self:verify_logging()

    if not self.detection_methods then
        return
    end
    vim.schedule(function()
        vim.notify(
            '(project.nvim): `detection_methods` has been deprecated!\nUse `use_lsp` instead.',
            WARN
        )
    end)
end

---@param opts? Project.Config.Options
---@return Project.Config.Options
function DEFAULTS:new(opts)
    vim.validate('opts', opts, { 'table', 'nil' }, true, 'Project.Config.Options')

    ---@type Project.Config.Options
    local obj = setmetatable(vim.tbl_deep_extend('keep', opts or {}, DEFAULTS), {
        __index = DEFAULTS,
    })
    return obj
end

return DEFAULTS
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
