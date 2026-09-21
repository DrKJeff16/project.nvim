---@module 'project._meta'

local Util = require('project.util')

local float = nil ---@type Project.ConfigLoc|nil|?
local detection_methods = {} ---@type ('lsp'|'pattern'|'git')[]

---@class Project.Config
local M = {}

---Get the default options for configuring `project`.
--- ---
---@return ProjectDefaults defaults
---@nodiscard
function M.get_defaults()
  return require('project.config.defaults'):new()
end

local options = M.get_defaults()

---@return ProjectDefaults options
function M.get()
  return options
end

---@param k string|table<string, any>
---@param v? any
function M.set(k, v)
  Util.validate({ k = { k, { 'string', 'table' } } })

  local dfts = M.get_defaults()
  if type(k) == 'string' and dfts[k] then
    options[k] = v
  elseif type(k) == 'table' then
    for key, val in pairs(k) do
      if dfts[key] then
        options[key] = val
      end
    end
  end
end

---@return ('lsp'|'pattern'|'git')[] detection_methods
---@nodiscard
function M.get_detection_methods()
  return detection_methods
end

---The function called when running `require('project').setup()`.
--- ---
---@param opts? ProjectOpts The `project.nvim` config options.
function M.setup(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  options = M.get_defaults():new(opts or {})

  detection_methods = options:gen_methods()
  options:expand_excluded()
  options.exclude_dirs = vim.tbl_map(Util.globtopattern.pattern_exclude, options.exclude_dirs)

  options:verify()

  ---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/111
  if options.enable_autochdir ~= nil then
    vim.o.autochdir = options.enable_autochdir
  end

  Util.path.datapath = options.history.save_dir
  Util.path.projectpath = Util.path.join(options.history.save_dir, 'project_nvim')

  -- WARN: THIS GOES FIRST!!!!
  if not Util.path.exists(Util.path.projectpath) and vim.fn.mkdir(Util.path.projectpath, 'p') ~= 1 then
    Util.path.datapath = M.get_defaults():_get_no_mt().history.save_dir
    Util.path.projectpath = Util.path.join(Util.path.projectpath, 'project_nvim')
    if not Util.path.exists(Util.path.projectpath) and vim.fn.mkdir(Util.path.projectpath, 'p') ~= 1 then
      error('(project.config.setup): Unable to create history directory!')
    end
  end

  if not Util.path.exists(Util.path.projectpath) and vim.fn.mkdir(Util.path.projectpath, 'p') ~= 1 then
    error('(project.config.setup): Unable to create history subdirectory!')
  end

  Util.path.historyfile = Util.path.join(Util.path.projectpath, options.history.save_file)
  if not Util.path.exists(Util.path.historyfile) then
    local fd = vim.uv.fs_open(Util.path.historyfile, 'w', Util.path.open_mode('644'))
    if not fd then
      error('(project.config.setup): Unable to create history file!')
    end

    vim.uv.fs_write(fd, { '[', ']' })
    vim.uv.fs_close(fd)
  end

  if not (Util.path.datapath and Util.path.projectpath and Util.path.historyfile) then
    error('(project.config.setup): Failed to store history path successfully!')
  end

  if options.log.enabled then
    Util.log.setup(options.log)
    Util.log.debug('(project.config.setup): Initialized logging.')
  end

  if vim.g.project_setup ~= 1 then
    vim.g.project_setup = 1
    Util.log.debug('(project.config.setup): `g:project_setup` set to `1`.')
  end

  require('project.util.history').setup()

  require('project.commands').setup()
  Util.log.debug('(project.config.setup): User commands created.')

  require('project.core').setup()

  if options.fzf_lua.enabled then
    Util.log.debug('(project.config.setup): fzf-lua integration enabled.')
    require('project.extensions.fzf-lua').setup()
  end
  if options.picker.enabled then
    Util.log.debug('(project.config.setup): picker.nvim integration enabled.')
    require('project.extensions.picker').setup()
  end
  if options.snacks.enabled then
    Util.log.debug('(project.config.setup): snacks.nvim integration enabled.')
    require('project.extensions.snacks').setup(options.snacks.opts or {})
  end

  if options.spinner.enabled then
    require('project.util.spinner').setup(options.spinner.kind)
  end

  local group = vim.api.nvim_create_augroup('project.nvim-attach', { clear = true })
  vim.api.nvim_create_autocmd('User', {
    pattern = 'ProjectAttachPre',
    group = group,
    callback = function(ev)
      if options.before_attach and vim.is_callable(options.before_attach) then
        options.before_attach(ev.data.dir, ev.data.method, ev.data.bufnr)
        Util.log.debug('(project.config.setup): Ran `before_attach` hook successfully.')
      end
    end,
  })
  vim.api.nvim_create_autocmd('User', {
    pattern = 'ProjectAttachPost',
    group = group,
    callback = function(ev)
      if options.on_attach and vim.is_callable(options.on_attach) then
        options.on_attach(ev.data.dir, ev.data.method, ev.data.bufnr, Util.map_attach)
        Util.log.debug('(project.config.setup): Ran `on_attach` hook successfully.')
      end
    end,
  })
end

---@return string config
---@nodiscard
function M.get_config()
  if vim.g.project_setup ~= 1 then
    Util.log.error('(project.config.get_config): `project.nvim` is not set up!')
    error('(project.config.get_config): `project.nvim` is not set up!')
  end
  local opts = options:_get_no_mt()
  table.sort(opts)
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

  float = { bufnr = bufnr, win = win }

  Util.optset('signcolumn', 'no', 'win', float.win)
  Util.optset('list', false, 'win', float.win)
  Util.optset('number', false, 'win', float.win)
  Util.optset('wrap', false, 'win', float.win)
  Util.optset('colorcolumn', '', 'win', float.win)
  Util.optset('filetype', '', 'buf', float.bufnr)
  Util.optset('fileencoding', 'utf-8', 'buf', float.bufnr)
  Util.optset('buftype', 'nowrite', 'buf', float.bufnr)
  Util.optset('modifiable', false, 'buf', float.bufnr)

  vim.keymap.set('n', 'q', M.close_win, { buffer = float.bufnr })
  vim.keymap.set('n', '<Esc>', M.close_win, { buffer = float.bufnr })
end

function M.close_win()
  if float then
    pcall(vim.api.nvim_buf_delete, float.bufnr, { force = true })
    pcall(vim.api.nvim_win_close, float.win, true)
    float = nil
  end
end

function M.toggle_win()
  if not float then
    M.open_win()
  else
    M.close_win()
  end
end

local Config = setmetatable(M, { ---@type Project.Config
  __index = function(self, k)
    local raw = rawget(self, k) or nil
    if raw then
      return raw
    end
    if Util.mod_exists('project.config.' .. k) then
      rawset(self, k, require('project.config.' .. k))
      return require('project.config.' .. k)
    end
  end,
})

return Config
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
