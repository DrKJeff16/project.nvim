---@enum (key) Project.Telescope.ActionNames
local action_names = { ---@diagnostic disable-line:unused-local
  browse_project_files = 1,
  change_working_directory = 1,
  delete_project = 1,
  find_project_files = 1,
  help_mappings = 1,
  recent_project_files = 1,
  search_in_project_files = 1,
}

---@enum (key) ProjectOpts.Show
local show = { ---@diagnostic disable-line:unused-local
  names = 1,
  paths = 1,
}

---@enum (key) ProjectOpts.ScopeChdir
local scope_chdir = { ---@diagnostic disable-line:unused-local
  global = 1,
  win = 1,
  tab = 1,
}

---@enum (key) ProjectOpts.Sort
local sort = { ---@diagnostic disable-line:unused-local
  newest = 1,
  oldest = 1,
}

---@class ProjectOpts.DisableOn
---@field ft? string[]
---@field bt? string[]

---@class ProjectDefaults.DisableOn: ProjectOpts.DisableOn
---@field ft string[]
---@field bt string[]

---@class Project.Telescope.Mappings
---Insert mode mappings.
---
---@field i? table<string, Project.Telescope.ActionNames>
---Normal mode mappings.
---
---@field n? table<string, Project.Telescope.ActionNames>

---@class Project.Telescope.DefaultMappings: Project.Telescope.Mappings
---@field i table<string, Project.Telescope.ActionNames>
---@field n table<string, Project.Telescope.ActionNames>

---Table of options used for control for detecting projects not owned by the current user.
--- ---
---@class ProjectOpts.DifferentOwners
---Determines whether a project will be added
---if its project root is owned by a different user.
---
---If `true`, it will add a project to the history even if its root
---is not owned by the current nvim `UID` **(UNIX only)**.
--- ---
---Default: `false`
--- ---
---@field allow? boolean
---If `true`, notify the user when a new project has a different UID **(UNIX only)**.
---
--- ---
---Default: `true`
--- ---
---@field notify? boolean

---@class ProjectDefaults.DifferentOwners: ProjectOpts.DifferentOwners
---@field allow boolean
---@field notify boolean

---Table of options used for history management.
--- ---
---@class ProjectOpts.History
---The directory in which `project.nvim` will store the project history.
---
---For more info, run `:lua vim.print(require('project').get_history_paths())`
--- ---
---Default: `vim.fn.stdpath('data')`
--- ---
---@field save_dir? string
---The history file name for `project.nvim`..
---
---If it doesn't end with `.json`, the file extension will be appended.
---
---If the string containes invalid chars (e.g. `/`, `\\`, `!`, `?`, etc.) an error will be raised,
--- ---
---Default: `'project_history.json'`
--- ---
---@field save_file? string
---The history file size. (by `@acristoffers`)
---
---This will indicate how many entries will be written to the history file.
---
---Set to `0` for no limit.
--- ---
---Default: `100`
--- ---
---@field size? integer

---@class ProjectDefaults.History: ProjectOpts.History
---@field save_dir string
---@field save_file string
---@field size integer

---Table of options used for the snacks picker.
--- ---
---@class ProjectOpts.Snacks
---Determines whether the `snacks.nvim` integration is enabled.
---
---If `snacks.nvim` is not installed, this won't make a difference.
--- ---
---Default: `false`
--- ---
---@field enabled? boolean
---@field opts? ProjectSnacksConfig
---@field show? ProjectOpts.Show

---@class ProjectDefaults.Snacks: ProjectOpts.Snacks
---@field enabled boolean
---@field opts ProjectSnacksConfig
---@field show ProjectOpts.Show

---Table of options used for the telescope picker.
--- ---
---@class ProjectOpts.Telescope
---Set this to `true` if you don't want the file picker to appear
---after you've selected a project.
---
---CREDITS: [UNKNOWN](https://github.com/ahmedkhalf/project.nvim/issues/157#issuecomment-2226419783)
--- ---
---Default: `false`
--- ---
---@field disable_file_picker? boolean
---Table of mappings for the Telescope picker.
---
---Only supports Normal and Insert modes.
--- ---
---Default: check the README
--- ---
---@field mappings? Project.Telescope.Mappings
---If you have `telescope-file-browser.nvim` installed, you can enable this
---so that the Telescope picker uses it instead of the `find_files` builtin.
---
---If `true`, use `telescope-file-browser.nvim` instead of builtins.
---In case it is not available, it'll fall back to `find_files`.
--- ---
---Default: `false`
--- ---
---@field prefer_file_browser? boolean
---@field show? ProjectOpts.Show
---Determines whether the newest projects come first in the
---telescope picker (`'newest'`), or the oldest (`'oldest'`).
--- ---
---Default: `'newest'`
--- ---
---@field sort? ProjectOpts.Sort

---@class ProjectDefaults.Telescope: ProjectOpts.Telescope
---@field disable_file_picker boolean
---@field mappings Project.Telescope.DefaultMappings
---@field prefer_file_browser boolean
---@field show ProjectOpts.Show
---@field sort ProjectOpts.Sort

---Options for logging utility.
--- ---
---@class ProjectOpts.Logging
---If `true`, it enables logging in the same directory in which your
---history file is stored.
--- ---
---Default: `false`
--- ---
---@field enabled? boolean
---Path in which the log file will be saved.
--- ---
---Default: `vim.fn.stdpath('state')`
--- ---
---@field logpath? string
---The maximum logfile size in [Gibibytes](https://simple.wikipedia.org/wiki/Gibibyte) (GiB).
--- ---
---Default: `1.1`
--- ---
---@field max_size? number

---@class ProjectDefaults.Logging: ProjectOpts.Logging
---@field enabled boolean
---@field logpath string
---@field max_size number

---Table of options used for `picker.nvim` integration
--- ---
---@class ProjectOpts.Picker
---Determines whether the `picker.nvim` integration is enabled.
---
---If `picker.nvim` is not installed, this won't make a difference.
--- ---
---Default: `false`
--- ---
---@field enabled? boolean
---Determines whether the picker called after selecting a project
---should list hidden files aswell or not.
---
--- ---
---Default: `false`
--- ---
---@field hidden? boolean
---@field show? ProjectOpts.Show
---Determines whether the newest projects come first (`'newest'`),
---or the oldest (`'oldest'`).
--- ---
---Default: `'newest'`
--- ---
---@field sort? ProjectOpts.Sort

---@class ProjectDefaults.Picker: ProjectOpts.Picker
---@field enabled boolean
---@field hidden boolean
---@field show ProjectOpts.Show
---@field sort ProjectOpts.Sort

---Table of options used for `fzf-lua` integration
--- ---
---@class ProjectOpts.FzfLua
---Determines whether the `fzf-lua` integration is enabled.
---
---If `fzf-lua` is not installed, this won't make a difference.
--- ---
---Default: `false`
--- ---
---@field enabled? boolean
---@field show? ProjectOpts.Show
---Determines whether the newest projects come first (`'newest'`),
---or the oldest (`'oldest'`).
--- ---
---Default: `'newest'`
--- ---
---@field sort? ProjectOpts.Sort

---@class ProjectDefaults.FzfLua: ProjectOpts.FzfLua
---@field enabled boolean
---@field show ProjectOpts.Show
---@field sort ProjectOpts.Sort

---Table containing all the LSP-adjacent options.
--- ---
---@class ProjectOpts.LSP
---If `true` then LSP-based method detection
---will take precedence over traditional pattern matching.
---
---See |project-nvim.pattern-matching| for more info.
--- ---
---Default: `true`
--- ---
---@field enabled? boolean
---Table of lsp clients to ignore by name,
---e.g. `{ 'efm', ... }`.
---
---If you have `nvim-lspconfig` installed **see** `:h lspconfig-all`
---for a list of servers.
--- ---
---Default: `{}`
--- ---
---@field ignore? string[]
---If `true` then LSP-based method detection
---will not be compared with pattern-matching-based detection.
---
---**WARNING: USE AT YOUR OWN DISCRETION!**
--- ---
---Default: `false`
--- ---
---@field no_fallback? boolean
---Sets whether to use Pattern Matching rules to the LSP client.
---
---If `false` the Pattern Matching will only apply
---to normal pattern matching.
---
---If `true` the `patterns` setting will also filter
---your LSP's `root_dir`, assuming there is one
---and `lsp.enabled` is set to `true`.
--- ---
---Default: `false`
--- ---
---@field use_pattern_matching? boolean

---@class ProjectDefaults.LSP: ProjectOpts.LSP
---@field enabled boolean
---@field ignore string[]
---@field no_fallback boolean
---@field use_pattern_matching boolean

---The options available for in `require('project').setup()`.
--- ---
---@class ProjectOpts
---Hook to run before attaching to a new project.
---
---It recieves `target_dir` and, optionally,
---the `method` used to change directory.
---
---Set to `nil` to disable.
---
---CREDITS: @danilevy1212
--- ---
---Default: `nil`
--- ---
---@field before_attach? nil|fun(target_dir: string, method: string)
---Table of options used for control for detecting projects not owned by the current user.
--- ---
---@field different_owners? ProjectOpts.DifferentOwners
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
---@field disable_on? ProjectOpts.DisableOn
---Don't calculate root dir on specific directories,
---e.g. `{ '~/.cargo/*', ... }`.
---
---For more info see `:h project-nvim.pattern-matching`.
--- ---
---Default: `{}`
--- ---
---@field exclude_dirs? string[]
---If enabled, set `vim.o.autochdir` to `true`.
---
---This is disabled by default because the plugin implicitly disables `autochdir`.
--- ---
---Default: `false`
--- ---
---@field enable_autochdir? boolean
---Table of options used for the `fzf-lua` integration
--- ---
---@field fzf_lua? ProjectOpts.FzfLua
---@field history? ProjectOpts.History
---Options for logging utility.
--- ---
---@field log? ProjectOpts.Logging
---Table containing all the LSP-adjacent options.
--- ---
---@field lsp? ProjectOpts.LSP
---If `true` your root directory won't be changed automatically,
---so you have the option to manually do so
---using the `:ProjectRoot` command.
--- ---
---Default: `false`
--- ---
---@field manual_mode? boolean
---All the patterns used to detect the project's root directory.
---
---See `:h project.nvim-pattern-matching`.
--- ---
---Default: `{ '.git', '.github', '_darcs', '.hg', '.bzr', '.svn', 'Pipfile', ... }`
--- ---
---@field patterns? string[]
---Hook to run after attaching to a new project.
---**_This only runs if the directory changes successfully._**
---
---It recieves `dir` and, optionally,
---the `method` used to change directory.
---
---Set to `nil` to disable.
---
---CREDITS: @danilevy1212
--- ---
---Default: `nil`
--- ---
---@field on_attach? nil|fun(dir: string, method: string)
---Table of options used for the `picker.nvim` integration
--- ---
---@field picker? ProjectOpts.Picker
---Determines the scope for changing the directory.
---
---Valid options are:
--- - `'global'`: All your nvim `cwd` will sync to your current buffer's project
--- - `'tab'`: _Per-tab_ `cwd` sync to the current buffer's project
--- - `'win'`: _Per-window_ `cwd` sync to the current buffer's project
--- ---
---Default: `'global'`
--- ---
---@field scope_chdir? ProjectOpts.ScopeChdir
---Make hidden files visible when using any picker.
--- ---
---Default: `false`
--- ---
---@field show_hidden? boolean
---If `false`, you'll get a _notification_ every time
---`project.nvim` changes directory.
---
---This is useful for debugging, or for players that
---enjoy verbose operations.
--- ---
---Default: `true`
--- ---
---@field silent_chdir? boolean
---Table of options used for the `snacks.nvim` picker.
--- ---
---@field snacks? ProjectOpts.Snacks
---Table of options used for the telescope picker.
--- ---
---@field telescope? ProjectOpts.Telescope

local MODSTR = 'project.config.defaults'
local WARN = vim.log.levels.WARN
local ERROR = vim.log.levels.ERROR
local Util = require('project.util')

---@class ProjectDefaults: ProjectOpts
---@field before_attach nil|fun(target_dir: string, method: string)
---@field different_owners ProjectDefaults.DifferentOwners
---@field disable_on ProjectDefaults.DisableOn
---@field enable_autochdir boolean
---@field exclude_dirs string[]
---@field expand_excluded fun(self: ProjectDefaults)
---@field fzf_lua ProjectDefaults.FzfLua
---@field gen_methods fun(self: ProjectDefaults): methods: { [1]: 'pattern' }|{ [1]: 'lsp', [2]: 'pattern' }
---@field history ProjectDefaults.History
---@field log ProjectDefaults.Logging
---@field lsp ProjectDefaults.LSP
---@field manual_mode boolean
---@field new fun(opts?: ProjectDefaults|ProjectOpts): defaults: ProjectDefaults
---@field on_attach nil|fun(dir: string, method: string)
---@field patterns string[]
---@field picker ProjectDefaults.Picker
---@field scope_chdir ProjectOpts.ScopeChdir
---@field show_hidden boolean
---@field silent_chdir boolean
---@field snacks ProjectDefaults.Snacks
---@field telescope ProjectDefaults.Telescope
---@field verify fun(self: ProjectDefaults)
---@field verify_datapath fun(self: ProjectDefaults)
---@field verify_fzf_lua fun(self: ProjectDefaults)
---@field verify_history fun(self: ProjectDefaults)
---@field verify_lists fun(self: ProjectDefaults)
---@field verify_logging fun(self: ProjectDefaults)
---@field verify_lsp fun(self: ProjectDefaults)
---@field verify_owners fun(self: ProjectDefaults)
---@field verify_scope_chdir fun(self: ProjectDefaults)

---@diagnostic disable-next-line:missing-fields
local DEFAULTS = { ---@type ProjectDefaults
  different_owners = { allow = false, notify = true },
  picker = { enabled = false, sort = 'newest', hidden = false, show = 'paths' },
  snacks = {
    enabled = false,
    show = 'paths',
    opts = {
      sort = 'newest',
      hidden = false,
      prompt = 'Select Project: ',
      layout = 'select',
      -- icon = {},
      -- path_icons = {},
    },
  },
  lsp = { enabled = true, ignore = {}, no_fallback = false, use_pattern_matching = false },
  manual_mode = false,
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
    '.csproj',
    '.sln',
    '.nvim.lua',
    '.neoconf.json',
    'neoconf.json',
  },
  before_attach = nil,
  on_attach = nil,
  enable_autochdir = false,
  show_hidden = false,
  exclude_dirs = {},
  silent_chdir = true,
  scope_chdir = 'global',
  disable_on = {
    ft = {
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
    bt = { 'help', 'nofile', 'nowrite', 'terminal' },
  },
  history = { save_dir = vim.fn.stdpath('data'), save_file = 'project_history.json', size = 100 },
  fzf_lua = { enabled = false, sort = 'newest', show = 'paths' },
  log = { enabled = false, max_size = 1.1, logpath = vim.fn.stdpath('state') },
  telescope = {
    sort = 'newest',
    show = 'paths',
    prefer_file_browser = false,
    disable_file_picker = false,
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
  },
}

---Checks the `historysize` option.
---
---If the option is not valid, a warning will be raised and
---the value will revert back to the default.
--- ---
function DEFAULTS:verify_history()
  Util.validate({ history = { self.history, { 'table', 'nil' }, true } })
  self.history = self.history or {}

  Util.validate({
    ['history.save_dir'] = { self.history.save_dir, { 'string', 'nil' }, true },
    ['history.save_file'] = { self.history.save_file, { 'string', 'nil' }, true },
    ['history.size'] = { self.history.size, { 'number', 'nil' }, true },
  })
  self.history.save_dir =
    Util.rstrip('/', vim.fn.fnamemodify(self.history.save_dir or DEFAULTS.history.save_dir, ':p'))

  self.history.save_file = self.history.save_file or DEFAULTS.history.save_file
  self.history.size = self.history.size or DEFAULTS.history.size
  if not Util.is_int(self.history.size, self.history.size >= 0) then
    self.history.size = DEFAULTS.history.size
  end

  if
    not Util.only_has_chars(
      self.history.save_file,
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_.',
      { spaces = true }
    )
  then
    error('(project.nvim): Invalid chars in `history.save_file` setup option!', ERROR)
  end

  if self.historysize and Util.is_int(self.historysize, self.historysize >= 0) then
    vim.notify(
      ('`options.historysize` is deprecated, use `options.history.size`!'):format(MODSTR),
      WARN
    )
    self.history.size = self.historysize
    self.historysize = nil ---@diagnostic disable-line:inject-field
  end
end

---Checks the `scope_chdir` option.
---
---If the option is not valid, a warning will be raised and
---the value will revert back to the default.
--- ---
function DEFAULTS:verify_scope_chdir()
  Util.validate({ scope_chdir = { self.scope_chdir, { 'string', 'nil' }, true } })

  if self.scope_chdir and vim.list_contains({ 'global', 'tab', 'win' }, self.scope_chdir) then
    return
  end

  vim.notify(
    ('`scope_chdir` option invalid (`%s`). Reverting to default option.'):format(self.scope_chdir),
    WARN
  )
  self.scope_chdir = DEFAULTS.scope_chdir
end

function DEFAULTS:verify_datapath()
  Util.validate({ history = { self.history, { 'table', 'nil' }, true } })
  self.history = self.history or {}

  Util.validate({ ['history.save_dir'] = { self.history.save_dir, { 'string', 'nil' }, true } })

  if self.datapath and Util.is_type('string', self.datapath) then
    vim.notify(
      ('`options.datapath` is deprecated, use `options.history.save_dir`!'):format(MODSTR),
      WARN
    )
    self.history.save_dir = self.datapath
    self.datapath = nil ---@diagnostic disable-line:inject-field
  end

  if not (self.history.save_dir and require('project.util').dir_exists(self.history.save_dir)) then
    vim.notify(('Invalid save_dir `%s`, reverting to default.'):format(self.history.save_dir), WARN)
    self.history.save_dir = DEFAULTS.history.save_dir
  end
end

---@return { [1]: 'pattern' }|{ [1]: 'lsp', [2]: 'pattern' } methods
---@nodiscard
function DEFAULTS:gen_methods()
  self:verify_lsp()
  local methods = { 'pattern' } ---@type { [1]: 'pattern' }|{ [1]: 'lsp', [2]: 'pattern' }
  if self.lsp.enabled then
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
  local Path = require('project.util.path')
  local log = self.log
  if not log or type(log) ~= 'table' then
    self.log = vim.deepcopy(DEFAULTS.log)
  end
  if self.logging ~= nil and type(self.logging) == 'boolean' then
    self.log.enabled = self.logging
    self.logging = nil ---@diagnostic disable-line:inject-field
    vim.notify(('`options.logging` is deprecated, use `options.log.enabled`!'):format(MODSTR), WARN)
  end

  ---@diagnostic disable:need-check-nil
  if not (Util.is_type('string', log.logpath) and Path.exists(log.logpath)) then
    self.log.logpath = DEFAULTS.log.logpath
  end
  if not (Util.is_type('number', log.max_size) and log.max_size > 0) then
    self.log.max_size = DEFAULTS.log.max_size
  end
  ---@diagnostic enable:need-check-nil
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

function DEFAULTS:verify_lsp()
  self.lsp = self.lsp and vim.tbl_deep_extend('keep', self.lsp, DEFAULTS.lsp) or DEFAULTS.lsp
  if self.use_lsp ~= nil then
    vim.notify('`use_lsp` is deprecated! Use `lsp.enabled` instead.', WARN)
    self.lsp.enabled = self.use_lsp
    self.use_lsp = nil ---@diagnostic disable-line:inject-field
  end
  if self.allow_patterns_for_lsp ~= nil then
    vim.notify(
      '`allow_patterns_for_lsp` is deprecated! Use `lsp.use_pattern_matching` instead.',
      WARN
    )
    self.lsp.use_pattern_matching = self.allow_patterns_for_lsp
    self.allow_patterns_for_lsp = nil ---@diagnostic disable-line:inject-field
  end
  if self.ignore_lsp and type(self.ignore_lsp) == 'table' then
    vim.notify('`ignore_lsp` is deprecated! Use `lsp.ignore` instead.', WARN)
    self.lsp.ignore = vim.deepcopy(self.ignore_lsp)
    self.ignore_lsp = nil ---@diagnostic disable-line:inject-field
  end
end

function DEFAULTS:verify_owners()
  self.different_owners = self.different_owners or {}
  if self.allow_different_owners ~= nil and type(self.allow_different_owners) == 'boolean' then
    vim.notify(
      '`allow_different_owners` is deprecated! Use `different_owners.allow` instead.',
      WARN
    )
    self.different_owners.allow = self.allow_different_owners
    self.allow_different_owners = nil ---@diagnostic disable-line:inject-field
  end
  if self.different_owners.allow == nil then
    self.different_owners.allow = false
  end
  if self.different_owners.notify == nil then
    self.different_owners.notify = true
  end
end

function DEFAULTS:verify_lists()
  local i, found = 1, {} ---@type integer, string[]
  while i <= #self.patterns and i > 0 do
    if
      not Util.is_type('string', self.patterns[i])
      or self.patterns[i] == ''
      or vim.list_contains(found, self.exclude_dirs[i])
    then
      table.remove(self.patterns, i)
      i = i - 1
    else
      table.insert(found, self.patterns[i])
      i = i + 1
    end
  end
  if vim.tbl_isempty(self.patterns) then
    self.patterns = vim.deepcopy(DEFAULTS.patterns)
  end

  i, found = 1, {}
  while i <= #self.exclude_dirs and i > 0 do
    if
      not Util.is_type('string', self.exclude_dirs[i])
      or self.exclude_dirs[i] == ''
      or vim.list_contains(found, self.exclude_dirs[i])
    then
      table.remove(self.exclude_dirs, i)
      i = i - 1
    else
      table.insert(found, self.exclude_dirs[i])
      i = i + 1
    end
  end

  i, found = 1, {}
  while i <= #self.lsp.ignore and i > 0 do
    if
      not Util.is_type('string', self.lsp.ignore[i])
      or self.lsp.ignore[i] == ''
      or vim.list_contains(found, self.exclude_dirs[i])
    then
      table.remove(self.lsp.ignore, i)
      i = i - 1
    else
      table.insert(found, self.lsp.ignore[i])
      i = i + 1
    end
  end
end

function DEFAULTS:verify_fzf_lua()
  Util.validate({ fzf_lua = { self.fzf_lua, { 'table', 'nil' }, true } })
  self.fzf_lua = self.fzf_lua or {}

  Util.validate({
    ['fzf_lua.enabled'] = { self.fzf_lua.enabled, { 'boolean', 'nil' }, true },
    ['fzf_lua.sort'] = { self.fzf_lua.sort, { 'string', 'nil' }, true },
  })
  self.fzf_lua.sort = self.fzf_lua.sort or 'newest'
  if self.fzf_lua.enabled == nil then
    self.fzf_lua.enabled = false
  end

  if vim.list_contains({ 'newest', 'oldest' }, self.fzf_lua.sort) then
    return
  end
  vim.notify(
    ('`fzf_lua.sort` is not a valid value! (`%s`)\nResetting to default'):format(self.fzf_lua.sort),
    vim.log.levels.ERROR
  )
  self.fzf_lua.sort = 'newest'
end

---Verify config integrity.
--- ---
function DEFAULTS:verify()
  local keys = vim.tbl_keys(DEFAULTS) ---@type string[]
  for k, _ in pairs(self) do
    if not vim.list_contains(keys, k) then
      self[k] = nil
    end
  end

  Util.validate({
    before_attach = { self.before_attach, { 'function', 'nil' }, true },
    different_owners = { self.different_owners, { 'table', 'nil' }, true },
    disable_on = { self.disable_on, { 'table', 'nil' }, true },
    enable_autochdir = { self.enable_autochdir, { 'boolean', 'nil' }, true },
    exclude_dirs = { self.exclude_dirs, { 'table', 'nil' }, true },
    fzf_lua = { self.fzf_lua, { 'table', 'nil' }, true },
    history = { self.history, { 'table', 'nil' }, true },
    log = { self.log, { 'table', 'nil' }, true },
    lsp = { self.lsp, { 'table', 'nil' }, true },
    manual_mode = { self.manual_mode, { 'boolean', 'nil' }, true },
    on_attach = { self.on_attach, { 'function', 'nil' }, true },
    patterns = { self.patterns, { 'table', 'nil' }, true },
    picker = { self.picker, { 'table', 'nil' }, true },
    scope_chdir = { self.scope_chdir, { 'string', 'nil' }, true },
    show_hidden = { self.show_hidden, { 'boolean', 'nil' }, true },
    silent_chdir = { self.silent_chdir, { 'boolean', 'nil' }, true },
    snacks = { self.snacks, { 'table', 'nil' }, true },
    telescope = { self.telescope, { 'table', 'nil' }, true },
  })

  self:verify_history()
  self:verify_datapath()
  self:verify_lsp()
  self:verify_scope_chdir()
  self:verify_logging()
  self:verify_owners()
  self:verify_lists()
  self:verify_fzf_lua()

  if not self.detection_methods then ---@diagnostic disable-line:undefined-field
    return
  end

  vim.notify(
    '(project.nvim): `detection_methods` has been deprecated!\nUse `lsp.enabled` instead.',
    WARN
  )
end

function DEFAULTS.new(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  local obj =
    setmetatable(vim.tbl_deep_extend('keep', opts or {}, DEFAULTS), { --[[@as ProjectDefaults]]
      __index = DEFAULTS,
    })
  return obj
end

return DEFAULTS
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
