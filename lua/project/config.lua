---@module 'project._meta'

local uv = vim.uv or vim.loop
local MODSTR = 'project.config'
local Extensions = require('project.extensions')
local Util = require('project.util')

local float = nil ---@type nil|Project.ConfigLoc

---Get the default options for configuring `project`.
--- ---
---@return ProjectDefaults defaults
---@nodiscard
local function get_defaults()
  return require('project.config.defaults')
end

---@class Project.Config
---@field custom_projects ProjectConfigHistoryEntry[]
---@field defaults ProjectDefaults
local M = {}

local options = get_defaults():new()

---@return ProjectDefaults options
function M.get()
  return options
end

---@param k string
---@param v any
function M.set(k, v)
  Util.validate({ k = { k, { 'string' } } })
  if not get_defaults():new()[k] then
    return
  end

  options[k] = v
end

---The function called when running `require('project').setup()`.
--- ---
---@param opts? ProjectOpts The `project.nvim` config options.
function M.setup(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  local pattern_exclude = Util.globtopattern.pattern_exclude
  options = get_defaults():new(opts or {})

  M.detection_methods = options:gen_methods()
  options:expand_excluded()
  options.exclude_dirs = vim.tbl_map(pattern_exclude, options.exclude_dirs)

  options:verify()

  ---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/111
  vim.o.autochdir = options.enable_autochdir

  Util.path.datapath = options.history.save_dir
  Util.path.projectpath = Util.path.join(options.history.save_dir, 'project_nvim')

  -- WARN: THIS GOES FIRST!!!!
  if vim.fn.mkdir(Util.path.projectpath, 'p') ~= 1 and not Util.path.exists(Util.path.projectpath) then
    Util.path.datapath = get_defaults():new():_get_no_mt().history.save_dir
    Util.path.projectpath = Util.path.join(Util.path.projectpath, 'project_nvim')
    if vim.fn.mkdir(Util.path.projectpath, 'p') ~= 1 and not Util.path.exists(Util.path.projectpath) then
      error('(%s.setup): Unable to create history directory!')
    end
  end

  if not Util.path.exists(Util.path.projectpath) and vim.fn.mkdir(Util.path.projectpath, 'p') ~= 1 then
    error('(%s.setup): Unable to create history subdirectory!')
  end

  Util.path.historyfile = Util.path.join(Util.path.projectpath, options.history.save_file)
  if not Util.path.exists(Util.path.historyfile) then
    local fd = uv.fs_open(Util.path.historyfile, 'w', Util.path.open_mode('644'))
    if not fd then
      error('(%s.setup): Unable to create history file!')
    end

    uv.fs_write(fd, '[]')
    uv.fs_close(fd)
  end

  if not (Util.path.datapath and Util.path.projectpath and Util.path.historyfile) then
    error(('(%s.setup): Failed to store history path successfully!'):format(MODSTR))
  end

  if options.log.enabled then
    Util.log.setup(options.log)
    Util.log.debug(('(%s.setup): Initialized logging.'):format(MODSTR))
  end

  if vim.g.project_setup ~= 1 then
    vim.g.project_setup = 1
    Util.log.debug(('(%s.setup): `g:project_setup` set to `1`.'):format(MODSTR))
  end

  require('project.commands').setup()
  Util.log.debug(('(%s.setup): User commands created.'):format(MODSTR))

  require('project.core').setup()

  if options.fzf_lua.enabled then
    Util.log.debug(('(%s.setup): fzf-lua integration enabled.'):format(MODSTR))
    Extensions['fzf-lua'].setup()
  end
  if options.picker.enabled then
    Util.log.debug(('(%s.setup): picker.nvim integration enabled.'):format(MODSTR))
    Extensions.picker.setup()
  end
  if options.snacks.enabled then
    Util.log.debug(('(%s.setup): snacks.nvim integration enabled.'):format(MODSTR))
    Extensions.snacks.setup(options.snacks.opts or {})
  end

  M.custom_projects = vim.deepcopy(options.custom_projects or {})

  local group = vim.api.nvim_create_augroup('project.nvim-attach', { clear = true })
  vim.api.nvim_create_autocmd('User', {
    pattern = 'ProjectAttachPre',
    group = group,
    callback = function(ev)
      if options.before_attach and vim.is_callable(options.before_attach) then
        options.before_attach(ev.data.dir, ev.data.method, ev.data.bufnr)
        Util.log.debug(('(%s.setup): Ran `before_attach` hook successfully.'):format(MODSTR))
      end
    end,
  })
  vim.api.nvim_create_autocmd('User', {
    pattern = 'ProjectAttachPost',
    group = group,
    callback = function(ev)
      if options.on_attach and vim.is_callable(options.on_attach) then
        options.on_attach(ev.data.dir, ev.data.method, ev.data.bufnr, Util.map_attach)
        Util.log.debug(('(%s.setup): Ran `on_attach` hook successfully.'):format(MODSTR))
      end
    end,
  })
end

---@return string config
---@nodiscard
function M.get_config()
  if vim.g.project_setup ~= 1 then
    Util.log.error(('(%s.get_config): `project.nvim` is not set up!'):format(MODSTR))
    error(('(%s.get_config): `project.nvim` is not set up!'):format(MODSTR))
  end
  local exceptions = {
    'expand_excluded',
    'gen_methods',
    'new',
    'verify',
    'verify_datapath',
    'verify_fzf_lua',
    'verify_history',
    'verify_lists',
    'verify_logging',
    'verify_lsp',
    'verify_owners',
    'verify_scope_chdir',
  }
  local opts = {} ---@type ProjectOpts
  for k, v in pairs(options) do
    if not vim.list_contains(exceptions, k) then
      opts[k] = v
    end
  end
  return vim.inspect(opts)
end

function M.open_win()
  if float then
    return
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  local height = math.floor(vim.o.lines * 0.85)
  local width = math.floor(vim.o.columns * 0.85)
  local title = 'project.nvim'
  local current_config = ('%s%s\n%s\n%s'):format(
    (' '):rep(math.floor((width - title:len()) / 2)),
    title,
    ('='):rep(width),
    M.get_config()
  )
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, vim.split(current_config, '\n', { plain = true }))

  if vim.fn.mode() ~= 'n' then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'i', false)
  end

  local win = vim.api.nvim_open_win(bufnr, true, {
    focusable = true,
    border = 'rounded',
    col = math.floor((vim.o.columns - width) / 2) - 1,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    relative = 'editor',
    style = 'minimal',
    title = 'Project Config',
    title_pos = 'center',
    width = width,
    height = height,
    zindex = 30,
  })

  Util.optset('signcolumn', 'no', 'win', win)
  Util.optset('list', false, 'win', win)
  Util.optset('number', false, 'win', win)
  Util.optset('wrap', false, 'win', win)
  Util.optset('colorcolumn', '', 'win', win)
  Util.optset('filetype', '', 'buf', bufnr)
  Util.optset('fileencoding', 'utf-8', 'buf', bufnr)
  Util.optset('buftype', 'nowrite', 'buf', bufnr)
  Util.optset('modifiable', false, 'buf', bufnr)

  vim.keymap.set('n', 'q', M.close_win, { buffer = bufnr })
  vim.keymap.set('n', '<Esc>', M.close_win, { buffer = bufnr })

  float = { bufnr = bufnr, win = win }
end

function M.close_win()
  if not float then
    return
  end

  pcall(vim.api.nvim_buf_delete, float.bufnr, { force = true })
  pcall(vim.api.nvim_win_close, float.win, true)

  float = nil
end

function M.toggle_win()
  if not float then
    M.open_win()
    return
  end

  M.close_win()
end

local Config = setmetatable(M, { ---@type Project.Config
  __index = function(self, k)
    if Util.mod_exists('project.config.' .. k) then
      return require('project.config.' .. k)
    end
    return rawget(self, k) or nil
  end,
})

return Config
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
