---@module 'project._meta'

local MODSTR = 'project.config.defaults'
local WARN = vim.log.levels.WARN
local Util = require('project.util')

local DEFAULTS = { ---@type ProjectConfigDefaults
  custom_projects = {},
  different_owners = { allow = false, notify = true },
  picker = { enabled = false, sort = 'newest', hidden = false, show = 'paths' },
  snacks = {
    enabled = false,
    opts = {
      sort = 'newest',
      hidden = false,
      prompt = 'Select Project: ',
      layout = 'select',
      -- icon = {},
      -- path_icons = {},
    },
    show = 'paths',
    tilde = false,
  },
  lsp = { enabled = true, ignore = {}, no_fallback = false, use_pattern_matching = false },
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
  manual_mode = false,
  remove_missing_dirs = true,
  enable_autochdir = false,
  show_by_name = false,
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
    disable_file_picker = false,
    prefer_file_browser = false,
    mappings = {
      n = {
        R = 'rename_project',
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
        ['<C-n>'] = 'rename_project',
        ['<C-r>'] = 'recent_project_files',
        ['<C-s>'] = 'search_in_project_files',
        ['<C-w>'] = 'change_working_directory',
      },
    },
    show = 'paths',
    sort = 'newest',
    tilde = false,
  },
}

---@diagnostic disable-next-line:missing-fields
local D = {} ---@type ProjectDefaults

D.__index = function(self, k)
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
  self.history = self.history or {}

  Util.validate({
    ['history.save_dir'] = { self.history.save_dir, { 'string', 'nil' }, true },
    ['history.save_file'] = { self.history.save_file, { 'string', 'nil' }, true },
    ['history.size'] = { self.history.size, { 'number', 'nil' }, true },
  })
  self.history.save_dir = Util.strip_slash(self.history.save_dir or DEFAULTS.history.save_dir)
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
    error('(project.nvim): Invalid chars in `history.save_file` setup option!')
  end

  if self.historysize and Util.is_int(self.historysize, self.historysize >= 0) then
    vim.notify(('`options.historysize` is deprecated, use `options.history.size`!'):format(MODSTR), WARN)
    self.history.size = self.historysize
    self.historysize = nil ---@diagnostic disable-line:inject-field
  end
end

---Checks the `scope_chdir` option.
---
---If the option is not valid, a warning will be raised and
---the value will revert back to the default.
--- ---
function D:verify_scope_chdir()
  Util.validate({ scope_chdir = { self.scope_chdir, { 'string', 'nil' }, true } })

  if self.scope_chdir and vim.list_contains({ 'global', 'tab', 'win' }, self.scope_chdir) then
    return
  end

  vim.notify(('`scope_chdir` option invalid (`%s`). Reverting to default option.'):format(self.scope_chdir), WARN)
  self.scope_chdir = DEFAULTS.scope_chdir
end

function D:verify_datapath()
  Util.validate({ history = { self.history, { 'table', 'nil' }, true } })
  self.history = self.history or {}

  Util.validate({ ['history.save_dir'] = { self.history.save_dir, { 'string', 'nil' }, true } })

  if self.datapath and Util.is_type('string', self.datapath) then
    vim.notify(('`options.datapath` is deprecated, use `options.history.save_dir`!'):format(MODSTR), WARN)
    self.history.save_dir = self.datapath
    self.datapath = nil ---@diagnostic disable-line:inject-field
  end

  if not (self.history.save_dir and Util.dir_exists(self.history.save_dir)) then
    vim.notify(('Invalid save_dir `%s`, reverting to default.'):format(self.history.save_dir), WARN)
    self.history.save_dir = DEFAULTS.history.save_dir
  end
end

---@return { [1]: 'pattern' }|{ [1]: 'lsp', [2]: 'pattern' } methods
---@nodiscard
function D:gen_methods()
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

function D:verify_logging()
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
  if not (Util.is_type('string', log.logpath) and Util.path.exists(log.logpath)) then
    self.log.logpath = DEFAULTS.log.logpath
  end
  if not (Util.is_type('number', log.max_size) and log.max_size > 0) then
    self.log.max_size = DEFAULTS.log.max_size
  end
  ---@diagnostic enable:need-check-nil
end

function D:expand_excluded()
  if not self.exclude_dirs or type(self.exclude_dirs) ~= 'table' then
    self.exclude_dirs = {}
  end
  if vim.tbl_isempty(self.exclude_dirs) then
    return
  end

  for i, v in ipairs(self.exclude_dirs) do
    self.exclude_dirs[i] = Util.rstrip('\\', Util.strip_slash(v))
  end
end

function D:verify_lsp()
  self.lsp = self.lsp and vim.tbl_deep_extend('keep', self.lsp, DEFAULTS.lsp) or DEFAULTS.lsp
  if self.use_lsp ~= nil then
    vim.notify('`use_lsp` is deprecated! Use `lsp.enabled` instead.', WARN)
    self.lsp.enabled = self.use_lsp
    self.use_lsp = nil ---@diagnostic disable-line:inject-field
  end
  if self.allow_patterns_for_lsp ~= nil then
    vim.notify('`allow_patterns_for_lsp` is deprecated! Use `lsp.use_pattern_matching` instead.', WARN)
    self.lsp.use_pattern_matching = self.allow_patterns_for_lsp
    self.allow_patterns_for_lsp = nil ---@diagnostic disable-line:inject-field
  end
  if self.ignore_lsp and type(self.ignore_lsp) == 'table' then
    vim.notify('`ignore_lsp` is deprecated! Use `lsp.ignore` instead.', WARN)
    self.lsp.ignore = vim.deepcopy(self.ignore_lsp)
    self.ignore_lsp = nil ---@diagnostic disable-line:inject-field
  end
end

function D:verify_owners()
  self.different_owners = self.different_owners or {}
  if self.allow_different_owners ~= nil and type(self.allow_different_owners) == 'boolean' then
    vim.notify('`allow_different_owners` is deprecated! Use `different_owners.allow` instead.', WARN)
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

function D:verify_lists()
  local i, found = 1, {} ---@type integer, string[]
  self.patterns = self.patterns or vim.deepcopy(DEFAULTS.patterns)
  while i <= #self.patterns and i > 0 do
    if
      not Util.is_type('string', self.patterns[i])
      or self.patterns[i] == ''
      or vim.list_contains(found, self.patterns[i])
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
  else
    self.patterns = Util.dedup(self.patterns)
  end

  self.disable_on = self.disable_on or vim.deepcopy(DEFAULTS.disable_on)

  self.disable_on.ft = self.disable_on.ft or vim.deepcopy(DEFAULTS.disable_on.ft)
  i, found = 1, {}
  while i <= #self.disable_on.ft and i > 0 do
    if not Util.is_type('string', self.disable_on.ft[i]) or self.disable_on.ft[i] == '' then
      table.remove(self.disable_on.ft, i)
      i = i - 1
    else
      table.insert(found, self.disable_on.ft[i])
      i = i + 1
    end
  end
  if vim.tbl_isempty(self.disable_on.ft) then
    self.disable_on.ft = vim.deepcopy(DEFAULTS.disable_on.ft)
  else
    self.disable_on.ft = Util.dedup(self.disable_on.ft)
  end

  self.disable_on.bt = self.disable_on.bt or vim.deepcopy(DEFAULTS.disable_on.bt)
  i, found = 1, {}
  while i <= #self.disable_on.bt and i > 0 do
    if not Util.is_type('string', self.disable_on.bt[i]) or self.disable_on.bt[i] == '' then
      table.remove(self.disable_on.bt, i)
      i = i - 1
    else
      table.insert(found, self.disable_on.bt[i])
      i = i + 1
    end
  end
  if vim.tbl_isempty(self.disable_on.bt) then
    self.disable_on.bt = vim.deepcopy(DEFAULTS.disable_on.bt)
  else
    self.disable_on.bt = Util.dedup(self.disable_on.bt)
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

function D:verify_fzf_lua()
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

  local keys = vim.tbl_keys(DEFAULTS) --[[@as string[]\]]
  table.insert(keys, 'on_attach')
  table.insert(keys, 'before_attach')
  keys = Util.dedup(keys)

  for k in pairs(self) do
    if not vim.list_contains(keys, k) then
      self[k] = nil
    end
  end

  if self.custom_projects and not vim.tbl_isempty(self.custom_projects) then
    if not vim.islist(self.custom_projects) then
      error(('`custom_projects` is not list-like:\n`%s`'):format(vim.inspect(self.custom_projects)))
    end

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

  if self.detection_methods then ---@diagnostic disable-line:undefined-field
    vim.notify('(project.nvim): `detection_methods` has been deprecated!\nUse `lsp.enabled` instead.', WARN)
  end
end

function D:_get_no_mt()
  ---@diagnostic disable-next-line:missing-fields
  local opts = {} ---@type ProjectConfigDefaults
  for _, k in pairs(vim.tbl_keys(self)) do
    ---@cast k string
    opts[k] = rawget(self, k)
  end
  return opts
end

function D:new(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  return setmetatable(vim.tbl_deep_extend('keep', opts or {}, DEFAULTS), D)
end

return D
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
