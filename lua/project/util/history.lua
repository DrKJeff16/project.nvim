---@module 'project._meta'

local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local INFO = vim.log.levels.INFO
local uv = vim.uv or vim.loop
local Log = require('project.util.log')
local Path = require('project.util.path')
local Util = require('project.util')

local event = nil ---@type uv.uv_fs_event_t|nil|?
local window = nil ---@type Project.HistoryWin|nil|?
local allowed_flags = {
  'a',
  'a+',
  'ax',
  'ax+',
  'r',
  'r+',
  'rs',
  'rs+',
  'sr',
  'sr+',
  'w',
  'w+',
  'wx',
  'wx+',
  'xa',
  'xa+',
  'xw',
  'xw+',
}

---@class Project.Util.History
---@field public historysize? integer
---Projects from previous neovim sessions.
--- ---
---@field public recent_projects ProjectHistoryEntry[]
---Projects from current neovim session.
--- ---
---@field public session_projects ProjectHistoryEntry[]
local M = {}

M.session_projects = {}
M.recent_projects = {}

---@param path string
---@param name string
---@return boolean success
function M.rename_project(path, name)
  Util.validate({
    path = { path, { 'string' } },
    name = { name, { 'string' } },
  })
  if vim.list_contains({ name, path }, '') then
    return false
  end

  path = Util.strip_slash(path)
  name = Util.strip(' ', name)

  local valid_chars = Util.dedup(
    vim.split(
      [[abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ@!_-?=+.,:;<>{}[]()'"^%$#&*`~| ]],
      '',
      { trimempty = false }
    )
  )
  for _, c in ipairs(vim.split(name, '', { trimempty = false })) do
    if not vim.list_contains(valid_chars, c) then
      Log.error(('(%s.rename_project): Invalid character `%s`!'):format(c))
      vim.notify(('(%s.rename_project): Invalid character `%s`!'):format(c), ERROR)
      return false
    end
  end

  local renamed = false
  local recent_i = 0
  local old_name = ''
  for i, proj in ipairs(M.recent_projects) do
    if proj.path == path then
      recent_i = i
      break
    end
  end
  if recent_i ~= 0 then
    old_name = M.recent_projects[recent_i].name
    M.recent_projects[recent_i].name = name
    renamed = true
  end

  local session_i = 0
  for i, proj in ipairs(M.session_projects) do
    if proj.path == path then
      session_i = i
      break
    end
  end
  if session_i ~= 0 then
    old_name = M.session_projects[session_i].name
    M.session_projects[session_i].name = name
    renamed = true
  end

  if renamed then
    vim.notify(('(project.util.history.rename_project): Renamed from `%s` to `%s`!'):format(old_name, name), INFO)
    Log.debug(('(project.util.history.rename_project): Renamed from `%s` to `%s`!'):format(old_name, name))

    M.write_history()
  end
  return renamed
end

---@param force? boolean
function M.clear_historyfile(force)
  Util.validate({ force = { force, { 'boolean', 'nil' }, true } })
  if force == nil then
    force = false
  end

  if vim.g.project_historyfile_cleared == 1 and not force then
    Log.info('(project.util.history.clear_historyfile): Already cleared. Aborting.')
    return
  end
  if not force and vim.fn.confirm('Are you sure you want to clear the project history?', '&Yes\n&No', 2) ~= 1 then
    Log.info('(project.util.history.clear_historyfile): Aborting.')
    return
  end

  local fd = Path.open_file(Path.historyfile, 'w')
  if not fd then
    Log.error('(project.util.history.clear_historyfile): Unable to clear history file!')
    vim.notify('(project.nvim): Unable to clear history file!', ERROR)
    return
  end

  local success = uv.fs_write(fd, { '[', ']' })
  uv.fs_close(fd)
  if not success then
    Log.error('(project.util.history.clear_historyfile): Unable to clear history file!')
    vim.notify('(project.nvim): Unable to clear history file!', ERROR)
    return
  end

  Log.warn('(project.util.history.clear_historyfile): History file cleared successfully.')
  vim.notify('(project.nvim): History file cleared successfully', WARN)

  M.recent_projects = {}
  M.session_projects = {}
  vim.g.project_historyfile_cleared = 1
end

---@param mode uv.fs_open.flags
---@return integer|nil|? fd
---@return uv.fs_stat.result|nil|? stat
function M.open_history(mode)
  Util.validate({ mode = { mode, { 'string', 'number' } } })
  if Util.is_type('string', mode) and not vim.list_contains(allowed_flags, mode) then
    Log.error(('(project.util.history.open_history): Invalid flag `%s`!'):format(mode))
    error(('(project.util.history.open_history): Invalid flag `%s`!'):format(mode))
  end

  Path.create_path()

  local dir_stat = uv.fs_stat(Path.projectpath)
  if not dir_stat then
    Log.error('(project.util.history.open_history): History directory unavailable!')
    error('(project.util.history.open_history): History directory unavailable!')
  end
  if not Path.exists(Path.historyfile) and vim.fn.writefile({ '[', ']' }, Path.historyfile) == -1 then
    Log.error('(project.util.history.open_history): History file unavailable!')
    error('(project.util.history.open_history): History file unavailable!')
  end

  return Path.open_file(Path.historyfile, mode)
end

---@param path string
---@param ind? integer|string
---@param force_name? boolean
function M.export_history_json(path, ind, force_name)
  Util.validate({
    path = { path, { 'string' } },
    ind = { ind, { 'string', 'number', 'nil' }, true },
    force_name = { force_name, { 'boolean', 'nil' }, true },
  })
  ind = ind or 2 --[[@as integer]]
  if force_name == nil then
    force_name = false
  end
  if Util.is_type('string', ind) then
    ---@cast ind string
    ind = math.floor(Path.open_mode(ind))
  end

  if vim.g.project_setup ~= 1 then
    Log.error('(project.util.history.export_history_json): `project.nvim` has not been configured!')
    vim.notify('(project.util.history.export_history_json): `project.nvim` has not been configured!', ERROR)
    return
  end

  local spc = nil ---@type string|nil|?
  if ind >= 1 then
    spc = (' '):rep(not vim.list_contains({ math.floor(ind), math.ceil(ind) }, ind) and math.floor(ind) or ind)
  end

  path = Util.strip(' ', path)
  if path == '' then
    Log.error(('(project.util.history.export_history_json): File does not exist! `%s`'):format(path))
    error(('(project.util.history.export_history_json): File does not exist! `%s`'):format(path))
  end
  if vim.fn.isdirectory(path) == 1 then
    Log.error(('(project.util.history.export_history_json): Target is a directory! `%s`'):format(path))
    error(('(project.util.history.export_history_json): Target is a directory! `%s`'):format(path))
  end

  path = Util.strip_slash(path)
  if path:sub(-5) ~= '.json' and not force_name then
    path = ('%s.json'):format(path)
  end

  local stat = uv.fs_stat(path)
  if stat then
    if stat.type ~= 'file' then
      Log.error(('(project.util.history.export_history_json): Target exists and is not a file! `%s`'):format(path))
      error(('(project.util.history.export_history_json): Target exists and is not a file! `%s`'):format(path))
    end

    if
      stat.size ~= 0
      and vim.fn.confirm(('File exists! Do you really want to export to it?'):format(path), '&Yes\n&No', 2) ~= 1
    then
      Log.info('(%s.delete_project): Aborting project export.')
      return
    end
  end

  M.write_history()

  if not Path.exists(path) then
    if Util.dir_exists(path) then
      return
    end
    if vim.fn.writefile({ '[]' }, path) ~= 0 then
      Log.error('(project.util.history.export_history_json): File restricted!')
      vim.notify('(project.util.history.export_history_json): File restricted!', ERROR)
      return
    end
  end

  local fd = Path.open_file(path, 'w')
  if not fd then
    Log.error(('(project.util.history.export_history_json): File restricted! `%s`'):format(path))
    vim.notify(('(project.util.history.export_history_json): File restricted! `%s`'):format(path), ERROR)
    return
  end

  local ok, data = pcall(vim.json.encode, Util.reverse(M.get_recent_projects()), { indent = spc })
  if ok and data then
    uv.fs_write(fd, data)

    Log.debug(('project.nvim - Exported history to `%s`'):format(Util.strip_slash(path, ':p:~')))
    vim.notify(('project.nvim - Exported history to `%s`'):format(Util.strip_slash(path, ':p:~')), INFO)
  end
  uv.fs_close(fd)
end

---@param path string
---@param force_name? boolean
---@param keep? boolean
function M.import_history_json(path, force_name, keep)
  Util.validate({
    path = { path, { 'string' } },
    force_name = { force_name, { 'boolean', 'nil' }, true },
    keep = { keep, { 'boolean', 'nil' }, true },
  })
  if force_name == nil then
    force_name = false
  end
  if keep == nil then
    keep = true
  end

  if vim.g.project_setup ~= 1 then
    Log.error('(project.util.history.import_history_json): `project.nvim` has not been configured!')
    vim.notify('(project.util.history.import_history_json): `project.nvim` has not been configured!', ERROR)
    return
  end

  path = Util.strip(' ', path)
  if path == '' then
    Log.error(('(project.util.history.import_history_json): File does not exist! `%s`'):format(path))
    vim.notify(('(project.util.history.import_history_json): File does not exist! `%s`'):format(path), ERROR)
    return
  end
  if vim.fn.isdirectory(path) == 1 then
    Log.error(('(project.util.history.import_history_json): Target is a directory! `%s`'):format(path))
    vim.notify(('(project.util.history.import_history_json): Target is a directory! `%s`'):format(path), ERROR)
    return
  end

  if path:sub(-5) ~= '.json' and not force_name then
    path = ('%s.json'):format(path)
  end
  path = Util.strip_slash(path)

  local fd, stat = Path.open_file(path, 'r')
  if not fd then
    Log.error(('(project.util.history.import_history_json): File is restricted: `%s`'):format(path))
    vim.notify(('(project.util.history.import_history_json): File is restricted: `%s`'):format(path), ERROR)
    return
  end
  if not stat then
    Log.error(('(project.util.history.import_history_json): File stat unavailable: `%s`'):format(path))
    vim.notify(('(project.util.history.import_history_json): File stat unavailable: `%s`'):format(path), ERROR)
    return
  end

  local data = uv.fs_read(fd, stat.size)
  if not data or data == '' then
    Log.error(('(project.util.history.import_history_json): Data unavailable: `%s`'):format(path))
    vim.notify(('(project.util.history.import_history_json): Data unavailable: `%s`'):format(path), ERROR)
    return
  end

  local ok, hist = pcall(vim.json.decode, data, {}) ---@type boolean, ProjectHistoryEntry[]|nil|?
  if not (ok and hist) then
    Log.error(('(project.util.history.import_history_json): JSON decoding failed: `%s`'):format(path))
    vim.notify(('(project.util.history.import_history_json): JSON decoding failed: `%s`'):format(path), ERROR)
    return
  end

  M.recent_projects = Util.reverse(hist)
  M.write_history()

  Log.debug(('project.nvim - Imported history from `%s`'):format(Util.strip_slash(path, ':p:~')))
  vim.notify(('project.nvim - Imported history from `%s`'):format(Util.strip_slash(path, ':p:~')), INFO)

  if not keep and uv.fs_unlink(path) then
    Log.debug(('project.nvim - Deleted imported history file `%s`'):format(Util.strip_slash(path, ':p:~')))
    vim.notify(('project.nvim - Deleted imported history file `%s`'):format(Util.strip_slash(path, ':p:~')), INFO)
  end
end

---Remove a project from a session.
--- ---
---@param session string
---@param found boolean
---@return boolean found
function M.remove_session(session, found)
  Util.validate({
    session = { session, { 'string' } },
    found = { found, { 'boolean' } },
  })

  local new_sessions = {} ---@type ProjectHistoryEntry[]
  for _, v in ipairs(M.session_projects) do
    if v.path == session then
      found = true
    else
      table.insert(new_sessions, v)
    end
  end

  M.session_projects = vim.deepcopy(new_sessions)
  return found
end

---Remove a project from recent projects.
--- ---
---@param project string
---@return boolean found
function M.remove_recent(project)
  Util.validate({ project = { project, { 'string' } } })

  local found = false
  local new_recents = {} ---@type ProjectHistoryEntry[]
  for _, v in ipairs(M.recent_projects) do
    if v.path == project then
      found = true
    else
      table.insert(new_recents, v)
    end
  end

  M.recent_projects = vim.deepcopy(new_recents)
  return found
end

---Deletes a project string, or a Telescope Entry type.
--- ---
---@param project string|Project.ActionEntry
---@param prompt? boolean
function M.delete_project(project, prompt)
  Util.validate({
    project = { project, { 'string', 'table' } },
    prompt = { prompt, { 'boolean', 'nil' }, true },
  })
  if prompt == nil then
    prompt = false
  end

  ---@cast project Project.ActionEntry
  if Util.is_type('table', project) then
    Util.validate({ project_value = { project.value, { 'string' } } })
  end

  if not M.recent_projects then
    Log.error('(project.util.history.delete_project): `recent_projects` is `nil`, aborting.')
    vim.notify('(project.util.history.delete_project): `recent_projects` is `nil`, aborting.')
    return
  end

  ---@cast project string|Project.ActionEntry
  local proj = type(project) == 'string' and project or project.value
  if prompt and vim.fn.confirm(("Delete '%s' from project list?"):format(proj), '&Yes\n&No', 2) ~= 1 then
    Log.info('(project.util.history.delete_project): Aborting project deletion.')
    return
  end

  if M.remove_session(proj, M.remove_recent(proj)) then
    Log.info(('(project.util.history.delete_project): Deleting project `%s`.'):format(proj))
    vim.notify(('(project.util.history.delete_project): Deleting project `%s`.'):format(proj), INFO)
    M.write_history()
  end
end

---Deletes multiple projects with a single confirmation prompt.
--- ---
---@param projects string[] List of project paths to delete
---@param prompt? boolean Whether to prompt before deletion (default false)
---@return boolean deleted Whether any projects were deleted
function M.delete_projects(projects, prompt)
  Util.validate({
    projects = { projects, { 'table' } },
    prompt = { prompt, { 'boolean', 'nil' }, true },
  })
  if vim.tbl_isempty(projects) then
    return false
  end
  if prompt == nil then
    prompt = false
  end

  if prompt then
    local msg = ('Delete %d project(s) from history?\n\n%s\n'):format(#projects, table.concat(projects, '\n'))
    if vim.fn.confirm(msg, '&Yes\n&No', 2) ~= 1 then
      Log.info('(project.util.history.delete_projects): Aborting project deletion.')
      return false
    end
  end

  for _, path in ipairs(projects) do
    M.delete_project(path, false)
  end
  return true
end

---Splits data into table.
--- ---
---@param history_data string
---@param name_data string[]
function M.deserialize_history(history_data, name_data)
  Util.validate({
    history_data = { history_data, { 'string' } },
    name_data = { name_data, { 'table' } },
  })

  local Config = require('project.config').get()
  local projects, i = {}, 1 ---@type ProjectHistoryEntry[], integer
  for s in history_data:gmatch('[^\r\n]+') do
    if
      not Path.is_excluded(s)
      and ((Config.remove_missing_dirs and Path.exists(s)) or not Config.remove_missing_dirs)
    then
      table.insert(projects, { path = s, name = name_data[i] })
    end

    i = i + 1
  end
  M.recent_projects = Util.delete_duplicates(projects)
end

---Only runs once.
--- ---
local function setup_watch()
  if vim.g.project_history_has_watch_setup == 1 and event then
    return
  end

  event = uv.new_fs_event()
  if not event then
    Log.warn('project.nvim - Unable to create history file setup watch!')
    return
  end

  event:start(Path.historyfile, {}, function(err, _, events)
    if not err and events.change then
      M.recent_projects = {}
      M.read_history()
    end
  end)

  Log.debug('(project.util.history.setup_watch): Started history file setup watch!')
  vim.g.project_history_has_watch_setup = 1
end

function M.read_history()
  local fd, stat = M.open_history('r')
  if not fd then
    Log.error('(project.util.history.read_history): File descriptor for history file unavailable!')
    return
  end
  if not stat then
    Log.error('(project.util.history.read_history): Stat for history file unavailable!')
    uv.fs_close(fd)
    return
  end

  setup_watch()

  if stat.size == 0 and not vim.tbl_isempty(M.session_projects) then
    Log.warn(
      '(project.util.history.read_history): History file is empty. Defering call to `project.util.history.write_history()`'
    )
    vim.defer_fn(M.write_history, 10000)
    return
  end

  ---@type boolean, ProjectHistoryEntry[]|nil|?
  local ok, data = pcall(vim.json.decode, uv.fs_read(fd, stat.size))
  uv.fs_close(fd)
  if not (ok and data) then
    Log.error(([[
(project.util.history.read_history): Could not decode JSON data from history file!
(`stat.size = %s`)
    ]]):format(stat.size))
    return
  end

  local data_str, name_list = '', {} ---@type string, string[]
  for _, v in ipairs(data) do
    data_str = ('%s%s%s'):format(data_str, data_str == '' and '' or '\n', v.path)
    table.insert(name_list, v.name)
  end

  M.deserialize_history(data_str, name_list)
end

---@overload fun(): recents: ProjectHistoryEntry[]
---@overload fun(paths_only: false): recents: ProjectHistoryEntry[]
---@overload fun(paths_only?: false, tilde: boolean): recents: ProjectHistoryEntry[]
---@overload fun(paths_only: true): recents: string[]
---@overload fun(paths_only: true, tilde: boolean): recents: string[]
function M.get_recent_projects(paths_only, tilde)
  Util.validate({
    paths_only = { paths_only, { 'boolean', 'nil' }, true },
    tilde = { tilde, { 'boolean', 'nil' }, true },
  })
  if tilde == nil then
    tilde = false
  end
  if paths_only == nil then
    paths_only = false
  end

  local tbl = {} ---@type ProjectHistoryEntry[]
  if M.recent_projects then
    vim.list_extend(tbl, M.recent_projects)
    vim.list_extend(tbl, M.session_projects)
  else
    tbl = M.session_projects
  end
  tbl = Util.delete_duplicates(tbl)

  local idx, removed = 1, false
  while idx <= #tbl do
    local v = Util.strip_slash(tbl[idx].path)
    if not Path.exists(v) or Path.is_excluded(v) then
      table.remove(tbl, idx)
      removed = true
    else
      idx = idx + 1
    end
  end

  if removed then
    Log.info('(project.util.history.get_recent_projects): An entry has been removed from history. Writing.')
    M.write_history()
  end

  local recents = {} ---@type ProjectHistoryEntry[]
  for i, v in ipairs(tbl) do
    local dir = v.path
    if Util.dir_exists(dir) then
      dir = Util.strip_slash(dir, tilde and ':p:~' or nil)
      table.insert(recents, paths_only and dir or { path = dir, name = tbl[i].name })
    end
  end
  return Util.dedup(recents, 'name')
end

---Write projects to history file.
--- ---
---@param path? string
function M.write_history(path)
  Util.validate({ path = { path, { 'string', 'nil' }, true } })
  local Config = require('project.config').get()
  path = Util.strip_slash(
    path or Path.historyfile or vim.fs.joinpath(Config.history.save_dir, 'project_nvim', Config.history.save_file)
  )

  if not Path.exists(path) and vim.fn.writefile({ '[', ']' }, path) ~= 0 then
    Log.error('(project.util.history.write_history): History file unavailable!')
    error('(project.util.history.write_history): History file unavailable!')
  end

  local historysize = 100
  if Config.history and Config.history.size then
    historysize = Config.history.size
  end
  M.historysize = historysize >= 0 and historysize or 100

  local file_history = {} ---@type ProjectHistoryEntry[]
  local ok, fd, stat ---@type boolean, integer|nil|?, uv.fs_stat.result|nil|?
  if path == Path.historyfile then
    ok, fd, stat = pcall(M.open_history, 'r')
  else
    ok, fd, stat = pcall(Path.open_file, path, 'r')
  end

  if ok and fd and stat then
    local data = uv.fs_read(fd, stat.size)
    uv.fs_close(fd)
    if data then
      ok, file_history = pcall(vim.json.decode, data) ---@type boolean, ProjectHistoryEntry[]
      if not ok then
        Log.error('(project.util.history.write_history): Unable to decode JSON data!')
        error('(project.util.history.write_history): Unable to decode JSON data!')
      end
    end
  end

  local res, i = M.get_recent_projects(), 1
  while i < #file_history do
    local proj = file_history[i]
    if
      vim.tbl_contains(file_history, function(val)
        return vim.deep_equal(val, proj)
      end, { predicate = true })
      and not vim.tbl_contains(res, function(val)
        return vim.deep_equal(val, proj)
      end, { predicate = true })
    then
      table.remove(file_history, i)
      i = i > 1 and i - 1 or i
    else
      i = i + 1
    end
  end
  while i < #res do
    local proj = res[i]
    if
      not vim.tbl_contains(file_history, function(val)
        return vim.deep_equal(val, proj)
      end, { predicate = true })
    then
      table.insert(file_history, i)
    end
    i = i + 1
  end

  if M.historysize and M.historysize > 0 then
    file_history = #res > M.historysize and vim.list_slice(res, #res - M.historysize, #res) or res
  end

  if vim.tbl_isempty(file_history) then
    uv.fs_close(fd)

    if vim.g.project_history_no_data_notified ~= 1 then
      Log.error('(project.util.history.write_history): No data available to write!')
      vim.g.project_history_no_data_notified = 1
    end
    return
  end

  if path == Path.historyfile then
    fd = M.open_history('w')
  else
    fd = Path.open_file(path, 'w')
  end
  if not fd then
    Log.error('(project.util.history.write_history): File restricted!')
    error('(project.util.history.write_history): File restricted!')
  end

  local success, out = pcall(vim.json.encode, file_history) ---@type boolean, string|nil|?
  if not (success and out) then
    uv.fs_close(fd)
    Log.error('(project.util.history.write_history): Unable to encode JSON data!')
    error('(project.util.history.write_history): Unable to encode JSON data!')
  end

  uv.fs_write(fd, out)
  uv.fs_close(fd)
end

---@param search 'session'|'recent'
---@param value string
---@param key 'path'|'name'
---@return string|nil|? entry_field
function M.find_entry(search, value, key)
  Util.validate({
    search = { search, { 'string' } },
    value = { value, { 'string' } },
    key = { key, { 'string' } },
  })
  if not (vim.list_contains({ 'recent', 'session' }, search) and vim.list_contains({ 'path', 'name' }, key)) then
    return
  end

  M.read_history()
  if not M.recent_projects then
    return
  end

  for _, v in ipairs(search == 'session' and M.session_projects or M.recent_projects) do
    if (v.path == Util.strip_slash(value) or v.name == value) and v[key] then
      return v[key]
    end
  end
end

function M.open_win()
  if window then
    return
  end
  if not Path.historyfile then
    Log.error('(project.util.history.open_win): History file not available!')
    vim.notify('(project.util.history.open_win): History file not available!', ERROR)
    return
  end
  if not Path.exists(Path.historyfile) then
    Log.error('(project.util.history.open_win): Bad historyfile path!')
    vim.notify('(project.util.history.open_win): Bad historyfile path!', ERROR)
    return
  end

  local fd, stat = M.open_history('r')
  if not fd then
    Log.error('(project.util.history.open_win): File descriptor for history file unavailable!')
    return
  end
  if not stat then
    Log.error('(project.util.history.open_win): Stat for history file unavailable!')
    uv.fs_close(fd)
    return
  end

  local ok, data = pcall(vim.json.decode, uv.fs_read(fd, stat.size)) ---@type boolean, ProjectHistoryEntry[]|nil|?
  uv.fs_close(fd)
  if not (ok and data) then
    return
  end

  local bufnr = vim.api.nvim_create_buf(true, true)
  local tab = vim.api.nvim_open_tabpage(bufnr, true, { after = -1 })
  window = { bufnr = bufnr, win = vim.api.nvim_get_current_win(), tab = tab }

  local lines = {} ---@type string[]
  for _, entry in ipairs(data) do
    table.insert(lines, ('(%s) - %s'):format(entry.name, entry.path))
  end

  vim.api.nvim_buf_set_lines(window.bufnr, 0, 1, true, Util.reverse(lines))
  vim.api.nvim_buf_set_name(window.bufnr, 'Project History')

  Util.optset('signcolumn', 'no', 'win', window.win)
  Util.optset('list', false, 'win', window.win)
  Util.optset('number', false, 'win', window.win)
  Util.optset('wrap', false, 'win', window.win)
  Util.optset('colorcolumn', '', 'win', window.win)
  Util.optset('filetype', '', 'buf', window.bufnr)
  Util.optset('fileencoding', 'utf-8', 'buf', window.bufnr)
  Util.optset('buftype', 'nowrite', 'buf', window.bufnr)
  Util.optset('modifiable', false, 'buf', window.bufnr)

  vim.keymap.set('n', 'q', M.close_win, { buffer = window.bufnr, noremap = true, silent = true })
end

function M.close_win()
  if window then
    pcall(vim.api.nvim_buf_delete, window.bufnr, { force = true })
    pcall(vim.api.nvim_cmd, { cmd = 'tabclose', range = { window.tab } }, { output = false })
    window = nil
  end
end

function M.toggle_win()
  if not window then
    M.open_win()
  else
    M.close_win()
  end
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
