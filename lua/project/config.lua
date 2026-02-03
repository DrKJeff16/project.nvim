local MODSTR = 'project.config'
local ERROR = vim.log.levels.ERROR
local Util = require('project.util')

---@class Project.ConfigLoc
---@field bufnr integer
---@field win integer

---@class Project.Config
---@field float? Project.ConfigLoc
local Config = {}

---Get the default options for configuring `project`.
--- ---
---@return Project.Config.Defaults defaults
---@nodiscard
function Config.get_defaults()
  return require('project.config.defaults')
end

Config.options = setmetatable({}, { __index = Config.get_defaults() }) ---@type Project.Config.Defaults

---The function called when running `require('project').setup()`.
--- ---
---@param options? Project.Config.Options the `project.nvim` config options
function Config.setup(options)
  Util.validate({ options = { options, { 'table', 'nil' }, true } })

  local pattern_exclude = require('project.util.globtopattern').pattern_exclude
  Config.options = Config.get_defaults().new(options or {})

  Config.detection_methods = Config.options:gen_methods()

  Config.options:expand_excluded()

  Config.options.exclude_dirs = vim.tbl_map(pattern_exclude, Config.options.exclude_dirs)
  Config.options:verify()

  ---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/111
  vim.o.autochdir = Config.options.enable_autochdir

  require('project.util.path').init(Config.options.datapath) -- WARN: THIS GOES FIRST!!!!

  local Log = require('project.util.log')
  if Config.options.log.enabled then
    Log.init()
  end

  require('project.api').init()

  if vim.g.project_setup ~= 1 then
    vim.g.project_setup = 1
    Log.debug(('(%s.setup): `g:project_setup` set to `1`.'):format(MODSTR))
  end
  require('project.commands').create_user_commands()

  if Config.options.fzf_lua.enabled then
    require('project.extensions.fzf-lua').setup_commands()
  end
end

---@return string config
---@nodiscard
function Config.get_config()
  if vim.g.project_setup ~= 1 then
    require('project.util.log').error(
      ('(%s.get_config): `project.nvim` is not set up!'):format(MODSTR)
    )
    error(('(%s.get_config): `project.nvim` is not set up!'):format(MODSTR), ERROR)
  end
  local exceptions = {
    'gen_methods',
    'new',
    'verify',
    'verify_datapath',
    'verify_histsize',
    'verify_logging',
    'verify_lsp',
    'verify_methods',
    'verify_owners',
    'verify_scope_chdir',
  }
  local opts = {} ---@type Project.Config.Options
  for k, v in pairs(Config.options) do
    if not vim.list_contains(exceptions, k) then
      opts[k] = v
    end
  end
  return vim.inspect(opts)
end

function Config.open_win()
  if Config.float then
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
    Config.get_config()
  )
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, vim.split(current_config, '\n', { plain = true }))
  local win = vim.api.nvim_open_win(bufnr, true, {
    focusable = true,
    border = 'single',
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

  ---@type vim.api.keyset.option, vim.api.keyset.option
  local win_opts, buf_opts = { win = win }, { buf = bufnr }
  vim.api.nvim_set_option_value('signcolumn', 'no', win_opts)
  vim.api.nvim_set_option_value('list', false, win_opts)
  vim.api.nvim_set_option_value('number', false, win_opts)
  vim.api.nvim_set_option_value('wrap', false, win_opts)
  vim.api.nvim_set_option_value('colorcolumn', '', win_opts)
  vim.api.nvim_set_option_value('filetype', '', buf_opts)
  vim.api.nvim_set_option_value('fileencoding', 'utf-8', buf_opts)
  vim.api.nvim_set_option_value('buftype', 'nowrite', buf_opts)
  vim.api.nvim_set_option_value('modifiable', false, buf_opts)

  vim.keymap.set('n', 'q', Config.close_win, { buffer = bufnr })
  vim.keymap.set('n', '<Esc>', Config.close_win, { buffer = bufnr })

  Config.float = { bufnr = bufnr, win = win }
end

function Config.close_win()
  if not Config.float then
    return
  end

  pcall(vim.api.nvim_buf_delete, Config.float.bufnr, { force = true })
  pcall(vim.api.nvim_win_close, Config.float.win, true)

  Config.float = nil
end

function Config.toggle_win()
  if not Config.float then
    Config.open_win()
    return
  end

  Config.close_win()
end

return Config
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
