---@module 'project._meta'

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

local timer = nil ---@type uv.uv_timer_t|nil

---@class Project.Log
---@field public logfile? string
---@field public window? Project.LogWin
local M = {}

---@param lvl vim.log.levels
---@return fun(...: any): output: string|nil
local function gen_log(lvl)
  ---@param ... any
  ---@return string|nil output
  return function(...)
    if not Config.options.log.enabled then
      return
    end
    local msg = ''
    for i = 1, select('#', ...) do
      local sel = select(i, ...)
      if sel then
        if type(sel) == 'number' or type(sel) == 'boolean' then
          sel = tostring(sel)
        elseif not type(sel) == 'string' then
          sel = vim.inspect(sel)
        end
        msg = ('%s %s'):format(msg, sel)
      end
    end
    return M.write(('%s\n'):format(msg), lvl)
  end
end

M.debug = gen_log(DEBUG)
M.error = gen_log(ERROR)
M.info = gen_log(INFO)
M.trace = gen_log(TRACE)
M.warn = gen_log(WARN)

---@return string|nil data
function M.read_log()
  if not M.logfile then
    return
  end
  local stat = uv.fs_stat(M.logfile)
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
  if uv.fs_unlink(M.logfile) then
    vim.notify('(project.nvim): Log cleared successfully', INFO)
    vim.g.project_log_cleared = 1
  end
end

local function timer_cb()
  local stat = uv.fs_stat(M.logfile)
  if not stat or stat.size < math.floor(Config.options.log.max_size * 1024 * 1024) then
    return
  end

  local fd = uv.fs_open(M.logfile, 'w', Path.open_mode('644'))
  if not fd then
    return
  end

  local ok = uv.fs_ftruncate(fd, 0)
  uv.fs_close(fd)

  if ok then
    vim.notify(('(%s): `%s` has been cleared!'):format(MODSTR, Util.strip_slash(M.logfile, ':p:~')), INFO)
    return
  end

  vim.notify(('(%s): `%s` could not be cleared!'):format(MODSTR, Util.strip_slash(M.logfile, ':p:~')), ERROR)
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

  local group = vim.api.nvim_create_augroup('project.nvim.log', { clear = false })
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
  if vim.g.project_log_has_watch_setup == 1 then
    return
  end
  local event = uv.new_fs_event()
  if not event then
    return
  end
  event:start(M.logpath, {}, function(err, _, events)
    if err or not events.change then
      return
    end

    M.read_log()
  end)

  make_timer()
  vim.g.project_log_has_watch_setup = 1
end

---@param data string
---@param lvl vim.log.levels
---@return string|nil written_data
function M.write(data, lvl)
  if not Config.options.log.enabled or vim.g.project_log_cleared == 1 then
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

function M.create_commands()
  require('project.commands').new({
    {
      name = 'ProjectLog',
      callback = function(ctx)
        if vim.tbl_isempty(ctx.fargs) then
          M.toggle_win()
          return
        end

        local arg = ctx.fargs[1] ---@type 'clear'|'close'|'open'|'toggle'
        if not vim.list_contains({ 'clear', 'close', 'open', 'toggle' }, arg) then
          vim.notify('Usage - `:ProjectLog [clear|close|oppen|toggle]`', INFO)
          return
        end

        if arg == 'clear' then
          M.clear_log()
          return
        end
        if arg == 'close' then
          M.close_win()
          return
        end
        if arg == 'open' then
          M.open_win()
          return
        end

        M.toggle_win()
      end,
      desc = 'Either opens the `project.nvim` log or clears the log file if `clear` is passed',
      nargs = '?',
      complete = function(_, line)
        local args = vim.split(line, '%s+', { trimempty = false })
        if (args[1]:sub(-1) == '!' and #args == 1) or #args > 2 then
          return {}
        end
        local res = {}
        for _, comp in ipairs({ 'clear', 'close', 'open', 'toggle' }) do
          if vim.startswith(comp, args[2]) then
            table.insert(res, comp)
          end
        end
        table.sort(res)

        return res
      end,
    },
  })
end

---@param mode uv.fs_open.flags
---@return integer|nil fd
---@return uv.fs_stat.result|nil stat
function M.open(mode)
  Path.create_path(M.logpath)
  local dir_stat = uv.fs_stat(M.logpath)
  if not dir_stat or dir_stat.type ~= 'directory' then
    error(('(%s.open): Projectpath stat is not valid!'):format(MODSTR))
  end

  local stat = uv.fs_stat(M.logfile)
  local fd = uv.fs_open(M.logfile, mode, Path.open_mode('644'))
  return fd, stat
end

function M.setup()
  local log_cfg = Config.options.log or {}
  if not log_cfg.enabled then
    return
  end
  M.logpath = log_cfg.logpath
  M.logfile = vim.fs.joinpath(M.logpath, 'project.log')
  Path.create_path(M.logpath)

  local fd
  local stat = uv.fs_stat(M.logfile)
  if not stat then
    fd = M.open('w')
    uv.fs_close(fd)
    fd = nil
  end
  stat = uv.fs_stat(M.logfile) ---@type uv.fs_stat.result

  fd = M.open('a')
  local head = ('='):rep(45)
  uv.fs_write(fd, (stat.size >= 1 and '\n' or '') .. os.date(('%s    %s    %s\n'):format(head, '%x  (%H:%M:%S)', head)))

  setup_watch()
  M.create_commands()
end

function M.open_win()
  local enabled = Config.options.log.enabled
  if not (M.logfile and enabled) then
    return
  end
  if vim.g.project_log_cleared == 1 then
    vim.notify(('(%s.open_win): Log has been cleared. Try restarting.'):format(MODSTR), WARN)
    return
  end
  if not Path.exists(M.logfile) then
    error(('(%s.open_win): Bad logfile path!'):format(MODSTR))
  end

  if M.window then -- Log window appears to be open
    return
  end

  local stat = uv.fs_stat(M.logfile)
  if not stat then
    return
  end

  local fd = uv.fs_open(M.logfile, 'r', Path.open_mode('644'))
  if not fd then
    return
  end

  local data = uv.fs_read(fd, stat.size)
  if not data then
    return
  end

  vim.cmd.tabnew()
  vim.schedule(function()
    local bufnr = vim.api.nvim_get_current_buf()
    local win = vim.api.nvim_get_current_win()

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

    M.window = { win = win, bufnr = bufnr, tab = vim.api.nvim_get_current_tabpage() }
  end)
end

function M.close_win()
  if not M.window then
    return
  end

  pcall(vim.api.nvim_buf_delete, M.window.bufnr, { force = true })
  pcall(vim.api.nvim_cmd, { cmd = 'tabclose', range = { M.window.tab } }, { output = false })

  M.window = nil
end

function M.toggle_win()
  if not M.window then
    M.open_win()
    return
  end

  M.close_win()
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
