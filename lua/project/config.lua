---@module 'project._meta'

local MODSTR = 'project.config'
local ERROR = vim.log.levels.ERROR
local Util = require('project.util')

---Get the default options for configuring `project`.
--- ---
---@return ProjectDefaults defaults
---@nodiscard
local function get_defaults()
  return require('project.config.defaults')
end

---@class Project.Config
---@field float? Project.ConfigLoc
local M = {}

M.options = setmetatable({}, { __index = get_defaults() }) ---@type ProjectDefaults

---The function called when running `require('project').setup()`.
--- ---
---@param options? ProjectOpts The `project.nvim` config options.
function M.setup(options)
  Util.validate({ options = { options, { 'table', 'nil' }, true } })

  local pattern_exclude = require('project.util.globtopattern').pattern_exclude
  M.options = get_defaults().new(options or {})

  M.detection_methods = M.options:gen_methods()
  M.options:expand_excluded()
  M.options.exclude_dirs = vim.tbl_map(pattern_exclude, M.options.exclude_dirs)

  M.options:verify()

  ---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/111
  vim.o.autochdir = M.options.enable_autochdir

  -- WARN: THIS GOES FIRST!!!!
  require('project.util.path').setup(M.options.history.save_dir, M.options.history.save_file)

  local Log = require('project.util.log')
  if M.options.log.enabled then
    Log.setup()
    Log.debug(('(%s.setup): Initialized logging.'):format(MODSTR))
  end

  if vim.g.project_setup ~= 1 then
    vim.g.project_setup = 1
    Log.debug(('(%s.setup): `g:project_setup` set to `1`.'):format(MODSTR))
  end

  Log.debug(('(%s.setup): User commands created.'):format(MODSTR))
  require('project.commands').create_user_commands()

  require('project.core').setup()

  if M.options.fzf_lua.enabled then
    Log.debug(('(%s.setup): fzf-lua integration enabled.'):format(MODSTR))
    require('project.extensions.fzf-lua').setup()
  end
  if M.options.picker.enabled then
    Log.debug(('(%s.setup): picker.nvim integration enabled.'):format(MODSTR))
    require('project.extensions.picker').setup()
  end
  if M.options.snacks.enabled then
    Log.debug(('(%s.setup): snacks.nvim integration enabled.'):format(MODSTR))
    require('project.extensions.snacks').setup(M.options.snacks.opts or {})
  end
end

---@return string config
---@nodiscard
function M.get_config()
  if vim.g.project_setup ~= 1 then
    require('project.util.log').error(('(%s.get_config): `project.nvim` is not set up!'):format(MODSTR))
    error(('(%s.get_config): `project.nvim` is not set up!'):format(MODSTR), ERROR)
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
  for k, v in pairs(M.options) do
    if not vim.list_contains(exceptions, k) then
      opts[k] = v
    end
  end
  return vim.inspect(opts)
end

function M.open_win()
  if M.float then
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

  M.float = { bufnr = bufnr, win = win }
end

function M.close_win()
  if not M.float then
    return
  end

  pcall(vim.api.nvim_buf_delete, M.float.bufnr, { force = true })
  pcall(vim.api.nvim_win_close, M.float.win, true)

  M.float = nil
end

function M.toggle_win()
  if not M.float then
    M.open_win()
    return
  end

  M.close_win()
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
