---@module 'project._meta'
---@module 'snacks'

local uv = vim.uv or vim.loop
local MODSTR = 'project.util.log'
local TRACE = vim.log.levels.TRACE -- `0`
local DEBUG = vim.log.levels.DEBUG -- `1`
local INFO = vim.log.levels.INFO -- `2`
local WARN = vim.log.levels.WARN -- `3`
local ERROR = vim.log.levels.ERROR -- `4`
local Config = require('project.config')
local Path = require('project.util.path')
local Util = require('project.util')

local timer = nil ---@type uv.uv_timer_t|nil|?
local event = nil ---@type uv.uv_fs_event_t|nil|?
local window = nil ---@type Project.Util.Log.Win|nil|?
local logfile = nil ---@type string|nil|?
local snacks_enabled = false ---@type boolean
local snacks_style = 'fancy' ---@type ProjectLog.Snacks.Style

---@enum ProjectLog.Snacks.Levels
local snacks_levels = { [DEBUG] = 'debug', [INFO] = 'info', [WARN] = 'warn', [ERROR] = 'error' }

---@param msg string
---@param sel any
---@param space? boolean
---@return string msg
local function format_sel(msg, sel, space)
  Util.validate({
    msg = { msg, { 'string' } },
    space = { space, { 'boolean', 'nil' }, true },
  })
  if space == nil then
    space = true
  end

  if sel then
    if type(sel) == 'number' or type(sel) == 'boolean' then
      sel = tostring(sel)
    elseif type(sel) ~= 'string' then
      sel = vim.inspect(sel)
    end
    msg = ('%s%s%s'):format(msg, space and ' ' or '', sel)
  end
  return msg
end

---@class Project.Util.Log
local M = {}

---@class Project.Util.Log.Backtrace
---@field debug fun(...: any)
---@field error fun(...: any)
---@field info fun(...: any)
---@field trace fun(...: any)
---@field warn fun(...: any)
---@overload fun(lvl: 0|1|2|3|4, ...: any)
M.backtrace = setmetatable({}, {
  ---@param self Project.Util.Log.Backtrace
  ---@param lvl 0|1|2|3|4
  __call = function(self, lvl, ...)
    Util.validate({ lvl = { lvl, { 'number' } } })
    lvl = vim.list_contains({ DEBUG, INFO, WARN, TRACE, ERROR }, lvl) and lvl or INFO

    self[lvl](...)
  end,
})

local function fallback_error(...)
  local msg = ''
  for i = 1, select('#', ...) do
    msg = format_sel(msg, select(i, ...), i ~= 1)
  end

  error(msg)
end

M.backtrace.debug = fallback_error
M.backtrace.error = fallback_error
M.backtrace.info = fallback_error
M.backtrace.trace = fallback_error
M.backtrace.warn = fallback_error

local function gen_snacks_backtrace()
  if not (snacks_enabled and _G.Snacks) then
    return
  end

  local opts = { history = true, style = snacks_style, title = 'project.nvim' } ---@type snacks.notify.Opts
  for _, level in pairs(snacks_levels) do
    opts.level = snacks_levels[level]
    M.backtrace[level] = function(...)
      local msg = ''
      for i = 1, select('#', ...) do
        msg = format_sel(msg, select(i, ...), i ~= 1)
      end

      pcall(_G.Snacks.debug.backtrace, msg, opts)
      error(msg)
    end
  end
end

---@param lvl vim.log.levels
---@return fun(...: any): output: string|nil|?
local function gen_log(lvl)
  return function(...) ---@return string|nil|? output
    if Config.get().log.enabled then
      local msg = ''
      for i = 1, select('#', ...) do
        msg = format_sel(msg, select(i, ...), i ~= 1)
      end
      return M.write(('%s\n'):format(msg), lvl)
    end
  end
end

M.debug = gen_log(DEBUG)
M.error = gen_log(ERROR)
M.info = gen_log(INFO)
M.trace = gen_log(TRACE)
M.warn = gen_log(WARN)

---@return string|nil|? data
function M.read_log()
  if not logfile then
    return
  end
  local stat = uv.fs_stat(logfile)
  if not stat then
    return
  end
  local fd = M.open('r')
  if not fd then
    return
  end

  local data = uv.fs_read(fd, stat.size, -1)
  return data
end

function M.clear_log()
  if vim.g.project_log_loaded == 1 and uv.fs_unlink(logfile) then
    vim.notify('(project.nvim): Log cleared successfully', INFO)
    vim.g.project_log_cleared = 1
  end
end

local function timer_cb()
  local stat = uv.fs_stat(logfile)
  if not stat or stat.size < math.floor(Config.get().log.max_size * 1024 * 1024) then
    return
  end

  local fd = uv.fs_open(logfile, 'w', Path.open_mode('644'))
  if not fd then
    return
  end

  local ok = uv.fs_ftruncate(fd, 0)
  uv.fs_close(fd)

  if ok then
    vim.notify(('(%s.timer_cb): `%s` has been cleared!'):format(MODSTR, Util.strip_slash(logfile, ':p:~')), INFO)
    return
  end

  vim.notify(('(%s.timer_cb): `%s` could not be cleared!'):format(MODSTR, Util.strip_slash(logfile, ':p:~')), ERROR)
end

local function make_timer()
  if timer and timer:is_active() then
    return
  end

  timer = uv.new_timer()
  if not timer then
    return
  end

  timer:start(10000, 900000, vim.schedule_wrap(timer_cb))

  local group = vim.api.nvim_create_augroup('project.nvim.log', { clear = true })
  vim.api.nvim_create_autocmd({ 'VimLeavePre' }, {
    group = group,
    callback = function()
      if not (timer and timer:is_active()) then
        return
      end

      timer:stop()
      timer = nil
    end,
  })
end

---Only runs once.
--- ---
local function setup_watch()
  if vim.g.project_log_has_watch_setup == 1 and event then
    return
  end

  event = uv.new_fs_event()
  if event then
    event:start(M.logpath, {}, function(err, _, events)
      if err or not events.change then
        return
      end

      M.read_log()
    end)

    make_timer()
    vim.g.project_log_has_watch_setup = 1
  end
end

---@param data string
---@param lvl vim.log.levels
---@return string|nil|? written_data
function M.write(data, lvl)
  if not Config.get().log.enabled or vim.g.project_log_cleared == 1 then
    return
  end

  Util.validate({
    data = { data, { 'string' } },
    lvl = { lvl, { 'number' } },
  })

  local fd = M.open('a')
  if not fd then
    return
  end

  local PFX = {
    [TRACE] = '[TRACE] ',
    [DEBUG] = '[DEBUG] ',
    [INFO] = '[INFO]  ',
    [WARN] = '[WARN]  ',
    [ERROR] = '[ERROR] ',
  }

  local msg = os.date(('%s  ==>  %s%s'):format('%H:%M:%S', PFX[lvl], data)) --[[@as string]]
  uv.fs_write(fd, msg, -1)
  uv.fs_close(fd)
  return msg
end

---@param mode uv.fs_open.flags
---@return integer|nil|? fd
---@return uv.fs_stat.result|nil|? stat
function M.open(mode)
  Path.create_path(M.logpath)
  local dir_stat = uv.fs_stat(M.logpath)
  if not dir_stat or dir_stat.type ~= 'directory' then
    error(('(%s.open): Projectpath stat is not valid!'):format(MODSTR))
  end

  local stat = uv.fs_stat(logfile)
  local fd = uv.fs_open(logfile, mode, Path.open_mode('644'))
  return fd, stat
end

---@param opts ProjectDefaults.Logging
function M.setup(opts)
  Util.validate({ opts = { opts, { 'table' } } })
  if not opts.enabled then
    return
  end

  M.logpath = opts.logpath
  logfile = vim.fs.joinpath(M.logpath, 'project.log')
  Path.create_path(M.logpath)

  local fd
  local stat = uv.fs_stat(logfile)
  if not stat then
    fd = M.open('w')
    uv.fs_close(fd)
    fd = nil
  end
  stat = uv.fs_stat(logfile) ---@type uv.fs_stat.result

  fd = M.open('a')
  local head = ('='):rep(45)
  uv.fs_write(fd, (stat.size >= 1 and '\n' or '') .. os.date(('%s    %s    %s\n'):format(head, '%x  (%H:%M:%S)', head)))

  setup_watch()

  if opts.snacks.enabled then
    snacks_enabled = true
    gen_snacks_backtrace()
  end

  vim.g.project_log_loaded = 1
end

function M.open_win()
  if not (vim.g.project_log_loaded == 1 and logfile) or window then
    return
  end
  if vim.g.project_log_cleared == 1 then
    vim.notify(('(%s.open_win): Log has been cleared, try restarting.'):format(MODSTR), WARN)
    M.debug(('(%s.open_win): Log has been cleared, try restarting.'):format(MODSTR))
    return
  end
  if not Path.exists(logfile) then
    error(('(%s.open_win): Bad logfile path!'):format(MODSTR))
  end

  local stat = uv.fs_stat(logfile)
  if not stat then
    return
  end

  local fd = uv.fs_open(logfile, 'r', Path.open_mode('644'))
  if not fd then
    return
  end

  local data = uv.fs_read(fd, stat.size)
  uv.fs_close(fd)
  if not data then
    return
  end

  local bufnr = vim.api.nvim_create_buf(true, true)
  local tab = vim.api.nvim_open_tabpage(bufnr, true, { after = -1 })
  local win = vim.api.nvim_get_current_win()

  window = { win = win, bufnr = bufnr, tab = tab }

  vim.api.nvim_buf_set_name(bufnr, 'Project Log')
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, vim.split(data, '\n', { plain = true, trimempty = false }))

  Util.optset('signcolumn', 'no', 'win', win)
  Util.optset('list', false, 'win', win)
  Util.optset('number', false, 'win', win)
  Util.optset('wrap', false, 'win', win)
  Util.optset('colorcolumn', '', 'win', win)
  Util.optset('filetype', 'log', 'buf', bufnr)
  Util.optset('fileencoding', 'utf-8', 'buf', bufnr)
  Util.optset('buftype', 'nowrite', 'buf', bufnr)
  Util.optset('modifiable', false, 'buf', bufnr)

  vim.keymap.set('n', 'q', M.close_win, { buffer = bufnr })
end

function M.close_win()
  if vim.g.project_log_loaded == 1 and window then
    pcall(vim.api.nvim_buf_delete, window.bufnr, { force = true })
    pcall(vim.api.nvim_cmd, { cmd = 'tabclose', range = { window.tab } }, { output = false })
    window = nil
  end
end

function M.toggle_win()
  if vim.g.project_log_loaded == 1 then
    if not window then
      M.open_win()
    else
      M.close_win()
    end
  end
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
