local MODSTR = 'project.util.history'
local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local INFO = vim.log.levels.INFO
local uv = vim.uv or vim.loop
local floor = math.floor
local ceil = math.ceil
local Util = require('project.util')
local Path = require('project.util.path')
local Log = require('project.util.log')

---@class Project.HistoryLoc
---@field bufnr integer
---@field win integer

---@class Project.Util.History
---Projects from previous neovim sessions.
--- ---
---@field recent_projects? string[]
---@field has_watch_setup? boolean
---@field historysize? integer
---@field hist_loc? Project.HistoryLoc
local History = {}

---Projects from current neovim session.
--- ---
History.session_projects = {} ---@type string[]

---@param mode uv.fs_open.flags
---@return integer|nil fd
---@return uv.fs_stat.result|nil stat
function History.open_history(mode)
  Util.validate({ mode = { mode, { 'string', 'number' } } })

  Path.create_path()

  local dir_stat = uv.fs_stat(Path.projectpath)
  if not dir_stat then
    require('project.util.log').error(
      ('(%s.open_history): History file unavailable!'):format(MODSTR)
    )
    error(('(%s.open_history): History file unavailable!'):format(MODSTR), ERROR)
  end

  local stat = uv.fs_stat(Path.historyfile)
  local fd = uv.fs_open(Path.historyfile, mode, tonumber('644', 8))
  return fd, stat
end

---@param path string
---@param ind integer|string|nil
---@param force_name boolean|nil
---@overload fun(path: string)
---@overload fun(path: string, ind: integer|string)
---@overload fun(path: string, ind?: integer|string, force_name: boolean)
function History.export_history_json(path, ind, force_name)
  Util.validate({
    path = { path, { 'string' } },
    ind = { ind, { 'string', 'number', 'nil' }, true },
    force_name = { force_name, { 'boolean', 'nil' }, true },
  })
  ind = ind or 2
  ind = floor(tonumber(ind))
  force_name = force_name ~= nil and force_name or false
  if vim.g.project_setup ~= 1 then
    return
  end

  local spc = nil ---@type string|nil
  if ind >= 1 then
    spc = (' '):rep(not vim.list_contains({ floor(ind), ceil(ind) }, ind) and floor(ind) or ind)
  end

  path = Util.strip(' ', path)
  if path == '' then
    Log.error(('(%s.export_history_json): File does not exist! `%s`'):format(MODSTR, path))
    error(('(%s.export_history_json): File does not exist! `%s`'):format(MODSTR, path), ERROR)
  end
  if vim.fn.isdirectory(path) == 1 then
    Log.error(('(%s.export_history_json): Target is a directory! `%s`'):format(MODSTR, path))
    error(('(%s.export_history_json): Target is a directory! `%s`'):format(MODSTR, path), ERROR)
  end

  if path:sub(-5) ~= '.json' and not force_name then
    path = ('%s.json'):format(path)
  end
  path = vim.fn.fnamemodify(path, ':p')

  local stat = uv.fs_stat(path)
  if stat then
    if stat.type ~= 'file' then
      Log.error(
        ('(%s.export_history_json): Target exists and is not a file! `%s`'):format(MODSTR, path)
      )
      error(
        ('(%s.export_history_json): Target exists and is not a file! `%s`'):format(MODSTR, path),
        ERROR
      )
    end

    if stat.size ~= 0 then
      local choice = vim.fn.confirm(
        ('File exists! Do you really want to export to it?'):format(path),
        '&Yes\n&No',
        2
      )
      if choice ~= 1 then
        Log.info('(%s.delete_project): Aborting project export.')
        return
      end
    end
  end

  History.write_history()

  local fd = uv.fs_open(path, 'w', tonumber('644', 8))
  if not fd then
    Log.error(('(%s.export_history_json): File restricted! `%s`'):format(MODSTR, path))
    error(('(%s.export_history_json): File restricted! `%s`'):format(MODSTR, path), ERROR)
  end

  local data = vim.json.encode(Util.reverse(History.get_recent_projects()), { indent = spc })

  Log.debug(('(%s.export_history_json): Writing to file `%s`...'):format(MODSTR, path))
  uv.fs_write(fd, data)
  uv.fs_close(fd)
  Log.debug(('(%s.export_history_json): File descriptor closed'):format(MODSTR))

  vim.notify(('Exported history to `%s`'):format(vim.fn.fnamemodify(path, ':~')), INFO, {
    title = 'project.nvim',
  })
end

---@param path string
---@param force_name boolean
---@overload fun(path: string)
function History.import_history_json(path, force_name)
  Util.validate({
    path = { path, { 'string' } },
    force_name = { force_name, { 'boolean', 'nil' }, true },
  })
  force_name = force_name ~= nil and force_name or false

  if vim.g.project_setup ~= 1 then
    return
  end

  path = Util.strip(' ', path)
  if path == '' then
    Log.error(('(%s.import_history_json): File does not exist! `%s`'):format(MODSTR, path))
    error(('(%s.import_history_json): File does not exist! `%s`'):format(MODSTR, path), ERROR)
  end
  if vim.fn.isdirectory(path) == 1 then
    Log.error(('(%s.import_history_json): Target is a directory! `%s`'):format(MODSTR, path))
    error(('(%s.import_history_json): Target is a directory! `%s`'):format(MODSTR, path), ERROR)
  end

  if path:sub(-5) ~= '.json' and not force_name then
    path = ('%s.json'):format(path)
  end
  path = vim.fn.fnamemodify(path, ':p')

  local fd = uv.fs_open(path, 'r', tonumber('644', 8))
  if not fd then
    Log.error(('(%s.import_history_json): File restricted! `%s`'):format(MODSTR, path))
    error(('(%s.import_history_json): File restricted! `%s`'):format(MODSTR, path), ERROR)
  end

  local stat = uv.fs_fstat(fd)
  if not stat then
    Log.error(('(%s.import_history_json): File stat unavailable! `%s`'):format(MODSTR, path))
    error(('(%s.import_history_json): File stat unavailable! `%s`'):format(MODSTR, path), ERROR)
  end

  local data = uv.fs_read(fd, stat.size)
  if not data or data == '' then
    Log.error(('(%s.import_history_json): Data unavailable! `%s`'):format(MODSTR, path))
    error(('(%s.import_history_json): Data unavailable! `%s`'):format(MODSTR, path), ERROR)
  end

  local ok, hist = pcall(vim.json.decode, data, {}) ---@type boolean, string[]
  if not ok then
    Log.error(('(%s.import_history_json): JSON decoding failed! `%s`'):format(MODSTR, path))
    error(('(%s.import_history_json): JSON decoding failed! `%s`'):format(MODSTR, path), ERROR)
  end

  History.recent_projects = Util.reverse(hist)
  History.write_history()

  vim.notify(('Imported history from `%s`'):format(vim.fn.fnamemodify(path, ':~')), INFO, {
    title = 'project.nvim',
  })
end

---Remove a project from a session.
--- ---
---@param session string
---@param found boolean
---@return boolean found
function History.remove_session(session, found)
  Util.validate({
    session = { session, { 'string' } },
    found = { found, { 'boolean' } },
  })

  local new_tbl = {} ---@type string[]
  for _, v in ipairs(History.session_projects) do
    if v ~= session then
      table.insert(new_tbl, v)
    else
      found = true
    end
  end
  History.session_projects = vim.deepcopy(new_tbl)

  return found
end

---Remove a project from recent projects.
--- ---
---@param project string
---@return boolean found
function History.remove_recent(project)
  Util.validate({ project = { project, { 'string' } } })

  local new_tbl, found = {}, false ---@type string[], boolean
  for _, v in ipairs(History.recent_projects) do
    if v ~= project then
      table.insert(new_tbl, v)
    else
      found = true
    end
  end
  History.recent_projects = vim.deepcopy(new_tbl)

  return found
end

---Deletes a project string, or a Telescope Entry type.
--- ---
---@param project string|Project.ActionEntry
function History.delete_project(project)
  Util.validate({ project = { project, { 'string', 'table' } } })

  ---@cast project Project.ActionEntry
  if Util.is_type('table', project) then
    Util.validate({ project_value = { project.value, { 'string' } } })
  end

  if not History.recent_projects then
    Log.error(('(%s.delete_project): `recent_projects` is nil! Aborting.'):format(MODSTR))
    vim.notify(('(%s.delete_project): `recent_projects` is nil! Aborting.'):format(MODSTR))
    return
  end

  ---@cast project string|Project.ActionEntry
  local proj = type(project) == 'string' and project or project.value
  local found = false
  found = History.remove_recent(proj)
  found = History.remove_session(proj, found)

  if found then
    Log.info(('(%s.delete_project): Deleting project `%s`.'):format(MODSTR, proj))
    vim.notify(('(%s.delete_project): Deleting project `%s`.'):format(MODSTR, proj), INFO)
    History.write_history()
  end
end

---Splits data into table.
--- ---
---@param history_data string
function History.deserialize_history(history_data)
  Util.validate({ history_data = { history_data, { 'string' } } })

  local projects = {} ---@type string[]
  for s in history_data:gmatch('[^\r\n]+') do
    if not Path.is_excluded(s) and Util.dir_exists(s) then
      table.insert(projects, s)
    end
  end
  History.recent_projects = Util.delete_duplicates(projects)
end

---Only runs once.
--- ---
function History.setup_watch()
  if History.has_watch_setup then
    return
  end

  local event = uv.new_fs_event()
  if not event then
    return
  end
  event:start(Path.projectpath, {}, function(err, _, events)
    if err ~= nil or not events.change then
      return
    end
    History.recent_projects = nil
    History.read_history()
  end)
  History.has_watch_setup = true
end

function History.read_history()
  local fd, stat = History.open_history('r')
  if not stat then
    Log.error(('(%s.read_history): Stat for history file unavailable!'):format(MODSTR))
    if fd then
      uv.fs_close(fd)
    end
    return
  end
  if not fd then
    Log.error(('(%s.read_history): File descriptor for history file unavailable!'):format(MODSTR))
    return
  end

  History.setup_watch()

  if stat.size == 0 and History.session_projects then
    History.write_history()
    return
  end

  ---@type boolean, string[]|nil
  local ok, data = pcall(vim.json.decode, uv.fs_read(fd, stat.size))
  uv.fs_close(fd)
  if not (ok and data) then
    Log.error(
      ('(%s.read_history): Could not decode JSON data from history file! (`stat.size = %s`)'):format(
        MODSTR,
        stat.size
      )
    )
    vim.notify(
      ('(%s.read_history): Could not decode JSON data from history file! (`stat.size = %s`)'):format(
        MODSTR,
        stat.size
      )
    )
    return
  end

  local data_str = ''
  for _, v in pairs(data) do
    data_str = ('%s%s%s'):format(data_str, data_str == '' and '' or '\n', v)
  end

  History.deserialize_history(data_str)
end

---@param tilde boolean
---@return string[] recents
---@overload fun(): recents: string[]
function History.get_recent_projects(tilde)
  Util.validate({ tilde = { tilde, { 'boolean', 'nil' }, true } })
  tilde = tilde ~= nil and tilde or false

  local tbl = {} ---@type string[]
  if History.recent_projects then
    vim.list_extend(tbl, History.recent_projects)
    vim.list_extend(tbl, History.session_projects)
  else
    tbl = History.session_projects
  end
  tbl = Util.delete_duplicates(vim.deepcopy(tbl))

  local i, removed = 1, false
  while i <= #tbl do
    local v = tbl[i]
    if not Path.exists(v) or Path.is_excluded(v) then
      table.remove(tbl, i)
      removed = true
      i = i - 1
    end

    i = i + 1
  end

  if removed then
    History.write_history()
  end

  local recents = {} ---@type string[]
  for _, dir in ipairs(tbl) do
    if Util.dir_exists(dir) then
      table.insert(recents, tilde and vim.fn.fnamemodify(dir, ':~') or dir)
    end
  end
  return Util.dedup(recents)
end

---Write projects to history file.
--- ---
function History.write_history()
  History.historysize = require('project.config').options.historysize or 100

  local file_history = {} ---@type string[]
  local fd, stat = History.open_history('r')
  if fd and stat then
    local data = uv.fs_read(fd, stat.size)
    uv.fs_close(fd)
    if data then
      file_history = vim.json.decode(data) ---@type string[]
    end
  end

  local res = History.get_recent_projects()
  for _, proj in ipairs(file_history) do
    if not vim.list_contains(res, proj) then
      table.insert(res, proj)
    end
  end

  local tbl_out = vim.deepcopy(res)
  if History.historysize and History.historysize > 0 then
    tbl_out = #res > History.historysize and vim.list_slice(res, #res - History.historysize, #res)
      or res
  end

  if vim.tbl_isempty(tbl_out) then
    uv.fs_close(fd)
    Log.error(('(%s.write_history): No data available to write!'):format(MODSTR))
    vim.notify(('(%s.write_history): No data available to write!'):format(MODSTR), WARN)
    return
  end

  fd = History.open_history('w')
  if not fd then
    Log.error(('(%s.write_history): File restricted!'):format(MODSTR))
    error(('(%s.write_history): File restricted!'):format(MODSTR), ERROR)
  end

  ---@type boolean, string|nil
  local ok, out = pcall(vim.json.encode, tbl_out)
  if not (ok and out) then
    uv.fs_close(fd)
    Log.error(('(%s.write_history): Unable to encode JSON data!'):format(MODSTR))
    error(('(%s.write_history): Unable to encode JSON data!'):format(MODSTR), ERROR)
  end

  Log.debug(('(%s.write_history): Writing to `%s`'):format(MODSTR, Path.historyfile))
  uv.fs_write(fd, out)
  uv.fs_close(fd)
  Log.debug(('(%s.write_history): File descriptor closed!'):format(MODSTR))
end

function History.open_win()
  if not Path.historyfile then
    return
  end
  if not Path.exists(Path.historyfile) then
    require('project.util.log').error(('(%s.open_win): Bad historyfile path!'):format(MODSTR))
    error(('(%s.open_win): Bad historyfile path!'):format(MODSTR), ERROR)
  end
  if History.hist_loc then
    return
  end

  local fd, stat = History.open_history('r')
  if not stat then
    Log.error(('(%s.open_win): Stat for history file unavailable!'):format(MODSTR))
    if fd then
      uv.fs_close(fd)
    end
    return
  end
  if not fd then
    Log.error(('(%s.open_win): File descriptor for history file unavailable!'):format(MODSTR))
    return
  end

  ---@type boolean, string[]
  local ok, data = pcall(vim.json.decode, uv.fs_read(fd, stat.size))
  if not ok then
    uv.fs_close(fd)
    return
  end

  vim.cmd.tabnew()
  vim.schedule(function()
    History.hist_loc = {
      bufnr = vim.api.nvim_get_current_buf(),
      win = vim.api.nvim_get_current_win(),
    }

    vim.api.nvim_buf_set_lines(History.hist_loc.bufnr, 0, 1, true, Util.reverse(data))
    vim.api.nvim_buf_set_name(History.hist_loc.bufnr, 'Project History')

    local win_opts = { win = History.hist_loc.win } ---@type vim.api.keyset.option
    vim.api.nvim_set_option_value('signcolumn', 'no', win_opts)
    vim.api.nvim_set_option_value('list', false, win_opts)
    vim.api.nvim_set_option_value('number', false, win_opts)
    vim.api.nvim_set_option_value('wrap', false, win_opts)
    vim.api.nvim_set_option_value('colorcolumn', '', win_opts)

    local buf_opts = { buf = History.hist_loc.bufnr } ---@type vim.api.keyset.option
    vim.api.nvim_set_option_value('filetype', '', buf_opts)
    vim.api.nvim_set_option_value('fileencoding', 'utf-8', buf_opts)
    vim.api.nvim_set_option_value('buftype', 'nowrite', buf_opts)
    vim.api.nvim_set_option_value('modifiable', false, buf_opts)

    vim.keymap.set('n', 'q', History.close_win, {
      buffer = History.hist_loc.bufnr,
      noremap = true,
      silent = true,
    })
  end)
end

function History.close_win()
  if not History.hist_loc then
    return
  end

  pcall(vim.api.nvim_buf_delete, History.hist_loc.bufnr, { force = true })
  pcall(vim.cmd.tabclose)
  History.hist_loc = nil
end

function History.toggle_win()
  if not History.hist_loc then
    History.open_win()
    return
  end

  History.close_win()
end

return History
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
