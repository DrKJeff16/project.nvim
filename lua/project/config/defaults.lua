---@module 'project._meta'
---@diagnostic disable:inject-field,missing-fields

local WARN = vim.log.levels.WARN
local Util = require('project.util')

local TELESCOPE_MAPPING_OPS = {
  'browse_project_files',
  'change_cwd',
  'delete_project',
  'find_project_files',
  'help_mappings',
  'recent_project_files',
  'rename_project',
  'search_in_project_files',
}

local DEFAULTS = { ---@type ProjectConfigDefaults
  before_attach = nil,
  custom_projects = {},
  different_owners = { allow = false, notify = true },
  disable_on = {
    bt = { 'help', 'nofile', 'nowrite', 'terminal' },
    ft = {
      '',
      'NvimTree',
      'TelescopePrompt',
      'TelescopeResults',
      'alpha',
      'checkhealth',
      'dropbar_menu',
      'fzf',
      'lazy',
      'log',
      'ministarter',
      'neo-tree',
      'notify',
      'nvim-pack',
      'packer',
      'picker-prompt',
      'qf',
      'snacks_picker_input',
    },
  },
  enable_autochdir = false,
  exclude_dirs = {},
  fzf_lua = { enabled = false, show = 'paths', sort = 'newest' },
  history = { save_dir = vim.fn.stdpath('data'), save_file = 'project_history.json', size = 100 },
  log = {
    enabled = false,
    debug = false,
    debug_level = vim.log.levels.INFO,
    logpath = vim.fn.stdpath('state'),
    max_size = 1.1,
    snacks = { enabled = false, style = 'fancy' },
  },
  lsp = { enabled = true, ignore = {}, no_fallback = false, use_pattern_matching = false },
  manual_mode = false,
  on_attach = nil,
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
    '.stylua.toml',
    'stylua.toml',
  },
  picker = { enabled = false, hidden = false, show = 'paths', sort = 'newest' },
  remove_missing_dirs = true,
  scope_chdir = 'global',
  show_by_name = false,
  show_hidden = false,
  silent_chdir = true,
  snacks = {
    enabled = false,
    opts = { hidden = false, layout = 'select', prompt = 'Select Project: ', show = 'paths', sort = 'newest' },
    tilde = false,
  },
  spinner = { enabled = false, kind = 'cursor' },
  telescope = {
    behavior = 'explore',
    disable_file_picker = false,
    mappings = {
      i = {
        ['<C-b>'] = 'browse_project_files',
        ['<C-d>'] = 'delete_project',
        ['<C-f>'] = 'find_project_files',
        ['<C-n>'] = 'rename_project',
        ['<C-r>'] = 'recent_project_files',
        ['<C-s>'] = 'search_in_project_files',
        ['<C-w>'] = 'change_cwd',
      },
      n = {
        R = 'rename_project',
        b = 'browse_project_files',
        d = 'delete_project',
        f = 'find_project_files',
        r = 'recent_project_files',
        s = 'search_in_project_files',
        w = 'change_cwd',
      },
    },
    prefer_file_browser = false,
    show = 'paths',
    sort = 'newest',
    tilde = false,
  },
  use_git = true,
}

local D = {} ---@type ProjectDefaults

function D.__index(self, k)
  if not rawget(self, k) then
    return getmetatable(self)[k]
  end
  return rawget(self, k)
end

---Checks the `historysize` option.
---
---If the option is not valid, a warning will be raised and
---the value will revert back to the default.
--- ---
function D:verify_history()
  Util.validate({ history = { self.history, { 'table', 'nil' }, true } })
  self.history = self.history or vim.deepcopy(DEFAULTS.history)

  Util.validate({
    ['history.save_dir'] = { self.history.save_dir, { 'string', 'nil' }, true },
    ['history.save_file'] = { self.history.save_file, { 'string', 'nil' }, true },
    ['history.size'] = { self.history.size, { 'number', 'nil' }, true },
  })
  self.history.save_dir = Util.strip_slash(self.history.save_dir or DEFAULTS.history.save_dir)
  self.history.save_file = self.history.save_file or DEFAULTS.history.save_file
  self.history.size = (self.history.size and Util.is_int(self.history.size, self.history.size >= 0))
      and self.history.size
    or DEFAULTS.history.size

  if
    not Util.only_has_chars(
      self.history.save_file,
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_.',
      { spaces = true }
    )
  then
    error('(project.nvim): Invalid chars in `history.save_file` setup option!')
  end

  if self.historysize and Util.is_int(self.historysize, self.historysize >= 0) then
    vim.notify('project.nvim - `historysize` is deprecated, use `history.size` instead', WARN)
    self.history.size = self.historysize
    self.historysize = nil
  end
end

---Checks the `scope_chdir` option.
---
---If the option is not valid, a warning will be raised and
---the value will revert back to the default.
--- ---
function D:verify_scope_chdir()
  Util.validate({ scope_chdir = { self.scope_chdir, { 'string', 'nil' }, true } })

  if not (self.scope_chdir and vim.list_contains({ 'global', 'tab', 'win' }, self.scope_chdir)) then
    vim.notify(
      ('project.nvim - Invalid `scope_chdir` value (`%s`). Reverting to default option.'):format(self.scope_chdir),
      WARN
    )
    self.scope_chdir = DEFAULTS.scope_chdir
  end
end

function D:verify_datapath()
  Util.validate({ history = { self.history, { 'table', 'nil' }, true } })
  self.history = self.history or vim.deepcopy(DEFAULTS.history)

  Util.validate({ ['history.save_dir'] = { self.history.save_dir, { 'string', 'nil' }, true } })

  if self.datapath and type(self.datapath) == 'string' then
    vim.notify('project.nvim - `datapath` is deprecated, use `history.save_dir`!', WARN)
    self.history.save_dir = self.datapath
    self.datapath = nil
  end

  if not (self.history.save_dir and Util.dir_exists(self.history.save_dir)) then
    vim.notify(('project.nvim - Invalid save_dir `%s`, reverting to default.'):format(self.history.save_dir), WARN)
    self.history.save_dir = DEFAULTS.history.save_dir
  end
end

function D:gen_methods()
  self:verify_lsp()

  -- TODO: Figure out the best order for detection methods, or outright make it customizable again,
  -- though the latter WILL require a chunk of the code to be refactored!
  local methods = { 'pattern' } ---@type ('git'|'lsp'|'pattern')[]
  if self.use_git and Util.executable('git') then
    table.insert(methods, 1, 'git')
  end
  if self.lsp.enabled then
    table.insert(methods, 1, 'lsp')
  end

  return setmetatable(methods, {
    __index = methods,
    __newindex = function()
      vim.notify('project.nvim - Detection methods are immutable!', vim.log.levels.ERROR)
    end,
  })
end

function D:verify_logging()
  Util.validate({ log = { self.log, { 'table', 'nil' }, true } })
  self.log = self.log or vim.deepcopy(DEFAULTS.log)

  Util.validate({
    ['log.debug'] = { self.log.debug, { 'boolean', 'nil' }, true },
    ['log.debug_level'] = { self.log.debug_level, { 'number', 'nil' }, true },
    ['log.enabled'] = { self.log.enabled, { 'boolean', 'nil' }, true },
    ['log.logpath'] = { self.log.logpath, { 'string', 'nil' }, true },
    ['log.max_size'] = { self.log.max_size, { 'number', 'nil' }, true },
    ['log.snacks'] = { self.log.snacks, { 'table', 'nil' }, true },
  })

  if self.log.debug == nil then
    self.log.debug = false
  end
  if self.log.enabled == nil then
    self.log.enabled = false
  end

  self.log.max_size = (self.log.max_size and self.log.max_size > 0) and self.log.max_size or DEFAULTS.log.max_size
  self.log.snacks = vim.tbl_deep_extend('force', DEFAULTS.log.snacks, self.log.snacks or {})
  self.log.logpath = (self.log.logpath and Util.path.exists(self.log.logpath)) and self.log.logpath
    or DEFAULTS.log.logpath
  self.log.debug_level = (self.log.debug_level and vim.tbl_contains(vim.log.levels, self.log.debug_level))
      and self.log.debug_level
    or DEFAULTS.log.debug_level

  if self.logging ~= nil and type(self.logging) == 'boolean' then
    self.log.enabled = self.logging
    self.logging = nil
    vim.notify('project.nvim - `logging` is deprecated, use `log.enabled`!', WARN)
  end
end

function D:expand_excluded()
  Util.validate({ exclude_dirs = { self.exclude_dirs, { 'table', 'nil' }, true } })
  self.exclude_dirs = self.exclude_dirs or vim.deepcopy(DEFAULTS.exclude_dirs)
  for i, v in ipairs(self.exclude_dirs) do
    self.exclude_dirs[i] = Util.rstrip('\\', Util.strip_slash(v))
  end
end

function D:verify_lsp()
  self.lsp = self.lsp and vim.tbl_deep_extend('keep', self.lsp, DEFAULTS.lsp) or DEFAULTS.lsp
  if self.use_lsp ~= nil then
    vim.notify('project.nvim - `use_lsp` is deprecated! Use `lsp.enabled` instead.', WARN)
    self.lsp.enabled = self.use_lsp
    self.use_lsp = nil
  end
  if self.allow_patterns_for_lsp ~= nil then
    vim.notify('project.nvim - `allow_patterns_for_lsp` is deprecated! Use `lsp.use_pattern_matching` instead.', WARN)
    self.lsp.use_pattern_matching = self.allow_patterns_for_lsp
    self.allow_patterns_for_lsp = nil
  end
  if self.ignore_lsp and type(self.ignore_lsp) == 'table' then
    vim.notify('project.nvim - `ignore_lsp` is deprecated! Use `lsp.ignore` instead.', WARN)
    self.lsp.ignore = vim.deepcopy(self.ignore_lsp)
    self.ignore_lsp = nil
  end
end

function D:verify_owners()
  self.different_owners = self.different_owners or {}
  if self.allow_different_owners ~= nil and type(self.allow_different_owners) == 'boolean' then
    vim.notify('project.nvim - `allow_different_owners` is deprecated! Use `different_owners.allow` instead.', WARN)
    self.different_owners.allow = self.allow_different_owners
    self.allow_different_owners = nil
  end
  if self.different_owners.allow == nil then
    self.different_owners.allow = false
  end
  if self.different_owners.notify == nil then
    self.different_owners.notify = true
  end
end

function D:verify_lists()
  local i, found, n = 1, {}, 1 ---@type integer, string[], 1|-1
  self.patterns = self.patterns or vim.deepcopy(DEFAULTS.patterns)
  while i <= #self.patterns and i > 0 do
    if type(self.patterns[i]) ~= 'string' or self.patterns[i] == '' or vim.list_contains(found, self.patterns[i]) then
      table.remove(self.patterns, i)
      n = -1
    else
      table.insert(found, self.patterns[i])
      n = 1
    end
    i = i + n
  end
  self.patterns = Util.dedup(#self.patterns > 0 and self.patterns or DEFAULTS.patterns)

  self.disable_on = self.disable_on or vim.deepcopy(DEFAULTS.disable_on)
  self.disable_on.ft = Util.dedup(self.disable_on.ft or DEFAULTS.disable_on.ft)
  i, found = 1, {}
  while i <= #self.disable_on.ft and i > 0 do
    if type(self.disable_on.ft[i]) ~= 'string' or self.disable_on.ft[i] == '' then
      table.remove(self.disable_on.ft, i)
      n = -1
    else
      table.insert(found, self.disable_on.ft[i])
      n = 1
    end
    i = i + n
  end
  self.disable_on.ft = Util.dedup(#self.disable_on.ft > 0 and self.disable_on.ft or DEFAULTS.disable_on.ft)

  self.disable_on.bt = Util.dedup(self.disable_on.bt or DEFAULTS.disable_on.bt)
  i, found = 1, {}
  while i <= #self.disable_on.bt and i > 0 do
    if type(self.disable_on.bt[i]) ~= 'string' or self.disable_on.bt[i] == '' then
      table.remove(self.disable_on.bt, i)
      n = -1
    else
      table.insert(found, self.disable_on.bt[i])
      n = 1
    end
    i = i + n
  end
  self.disable_on.bt = Util.dedup(#self.disable_on.bt > 0 and self.disable_on.bt or DEFAULTS.disable_on.bt)

  i, found = 1, {}
  while i <= #self.exclude_dirs and i > 0 do
    if
      type(self.exclude_dirs[i]) ~= 'string'
      or self.exclude_dirs[i] == ''
      or vim.list_contains(found, self.exclude_dirs[i])
    then
      table.remove(self.exclude_dirs, i)
      n = -1
    else
      table.insert(found, self.exclude_dirs[i])
      n = 1
    end
    i = i + n
  end

  i, found = 1, {}
  while i <= #self.lsp.ignore and i > 0 do
    if
      type(self.lsp.ignore[i]) ~= 'string'
      or self.lsp.ignore[i] == ''
      or vim.list_contains(found, self.exclude_dirs[i])
    then
      table.remove(self.lsp.ignore, i)
      n = -1
    else
      table.insert(found, self.lsp.ignore[i])
      n = 1
    end
    i = i + n
  end
end

function D:verify_fzf_lua()
  Util.validate({ fzf_lua = { self.fzf_lua, { 'table', 'nil' }, true } })
  self.fzf_lua = self.fzf_lua or vim.deepcopy(DEFAULTS.fzf_lua)

  Util.validate({
    ['fzf_lua.enabled'] = { self.fzf_lua.enabled, { 'boolean', 'nil' }, true },
    ['fzf_lua.sort'] = { self.fzf_lua.sort, { 'string', 'nil' }, true },
  })
  self.fzf_lua.sort = self.fzf_lua.sort or 'newest'
  if self.fzf_lua.enabled == nil then
    self.fzf_lua.enabled = false
  end

  if not vim.list_contains({ 'newest', 'oldest' }, self.fzf_lua.sort) then
    vim.notify(
      ('project.nvim - `fzf_lua.sort` is not a valid value! (`%s`)\nResetting to default'):format(self.fzf_lua.sort),
      vim.log.levels.ERROR
    )
    self.fzf_lua.sort = 'newest'
  end
end

function D:verify_telescope()
  Util.validate({ telescope = { self.telescope, { 'table', 'nil' }, true } })
  self.telescope = vim.tbl_deep_extend('keep', self.telescope, DEFAULTS.telescope)

  Util.validate({
    ['telescope.behavior'] = { self.telescope.behavior, { 'string', 'nil' }, true },
  })

  self.telescope.behavior = self.telescope.behavior or DEFAULTS.telescope.behavior
  if not vim.list_contains({ 'explore', 'recent' }, self.telescope.behavior) then
    vim.notify(
      ('project.nvim - Invalid value for `telescope.behavior`: `%s`. Falling back to default value.'):format(
        self.telescope.behavior
      ),
      WARN
    )
    self.telescope.behavior = DEFAULTS.telescope.behavior
  end

  self.telescope.mappings = vim.tbl_deep_extend('keep', self.telescope.mappings, DEFAULTS.telescope.mappings)
  for lhs, maps in pairs(self.telescope.mappings) do
    ---@cast lhs 'i'|'n'
    ---@cast maps table<string, Project.Telescope.ActionNames>
    if vim.list_contains({ 'n', 'i' }, lhs) then
      for k, v in pairs(maps) do
        if v == 'change_working_directory' then
          vim.notify(
            ("project.nvim - telescope.mappings['%s']['%s'] with a value of 'change_working_directory' is deprecated!\nUse 'change_cwd' instead!"):format(
              lhs,
              k
            ),
            WARN
          )
          self.telescope.mappings[lhs][k] = 'change_cwd'
        elseif not vim.list_contains(TELESCOPE_MAPPING_OPS, v) then
          self.telescope.mappings[lhs][k] = nil
        end
      end
    else
      self.telescope.mappings[lhs] = nil
    end
  end
end

---Verify config integrity.
--- ---
function D:verify()
  Util.validate({
    before_attach = { self.before_attach, { 'function', 'nil' }, true },
    custom_projects = { self.custom_projects, { 'table', 'nil' }, true },
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
    show_by_name = { self.show_by_name, { 'boolean', 'nil' }, true },
    show_hidden = { self.show_hidden, { 'boolean', 'nil' }, true },
    silent_chdir = { self.silent_chdir, { 'boolean', 'nil' }, true },
    snacks = { self.snacks, { 'table', 'nil' }, true },
    spinner = { self.spinner, { 'table', 'nil' }, true },
    telescope = { self.telescope, { 'table', 'nil' }, true },
    use_git = { self.use_git, { 'boolean', 'nil' }, true },
  })

  self:verify_history()
  self:verify_datapath()
  self:verify_lsp()
  self:verify_scope_chdir()
  self:verify_logging()
  self:verify_owners()
  self:verify_lists()
  self:verify_fzf_lua()
  self:verify_telescope()

  local keys = vim.tbl_keys(DEFAULTS) --[[@as string[]\]]
  table.insert(keys, 'on_attach')
  table.insert(keys, 'before_attach')

  for k in pairs(self) do
    if not vim.list_contains(Util.dedup(keys), k) then
      self[k] = nil
    end
  end

  if self.custom_proects and not vim.islist(self.custom_projects) then
    error(('`custom_projects` is not list-like:\n`%s`'):format(vim.inspect(self.custom_projects)))
  end
  if self.custom_projects and #self.custom_projects > 0 then
    local custom_projects = {} ---@type ProjectConfigHistoryEntry[]
    for k, v in ipairs(self.custom_projects) do
      Util.validate({
        [('custom_projects[%d].path'):format(k)] = { v.path, { 'string' } },
        [('custom_projects[%d].name'):format(k)] = { v.name, { 'string', 'nil' }, true },
      })

      if Util.path_exists(Util.strip_slash(v.path)) then
        table.insert(custom_projects, {
          path = Util.strip_slash(v.path),
          name = v.name or Util.path.join(Util.strip_slash(v.path, ':p:h:h:t'), Util.strip_slash(v.path, ':p:h:t')),
        })
      end
    end
    self.custom_projects = vim.deepcopy(custom_projects)
  end

  if self.detection_methods then
    vim.notify('project.nvim - `detection_methods` has been deprecated!\nUse `lsp.enabled` instead.', WARN)
  end
end

function D:_get_no_mt()
  local opts = {} ---@type ProjectConfigDefaults
  for _, k in ipairs(vim.tbl_keys(self)) do
    ---@cast k string
    opts[k] = rawget(self, k)
  end
  return opts
end

function D:new(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  return setmetatable(vim.tbl_deep_extend('force', DEFAULTS, opts or {}), D) --[[@as ProjectDefaults]]
end

return D
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
