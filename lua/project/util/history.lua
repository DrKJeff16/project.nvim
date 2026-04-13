local MODSTR = 'project.util.history'
local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local INFO = vim.log.levels.INFO
local uv = vim.uv or vim.loop
local Util = require('project.util')
local Path = require('project.util.path')
local Log = require('project.util.log')

---@class ProjectHistoryEntry
---@field name string
---@field path string

---@class Project.HistoryWin
---@field bufnr integer
---@field tab integer
---@field win integer

---@class Project.Util.History
---@field has_watch_setup? boolean
---@field historysize? integer
---@field legacy? boolean
---Projects from previous neovim sessions.
--- ---
---@field recent_projects? string[]|ProjectHistoryEntry[]
---Projects from current neovim session.
--- ---
---@field session_projects string[]|ProjectHistoryEntry[]
---@field window? Project.HistoryWin
local M = {}

M.session_projects = {}

function M.migrate()
  if M.recent_projects and Util.same_type_list(M.recent_projects, 'string') then
    for i, v in ipairs(M.recent_projects) do
      M.recent_projects[i] = {
        path = v,
        name = vim.fn.fnamemodify(v, ':p:h:h:t') .. '/' .. vim.fn.fnamemodify(v, ':p:h:t'),
      }
    end
  end

  if
    not vim.tbl_isempty(M.session_projects)
    and Util.same_type_list(M.session_projects, 'string')
  then
    for i, v in ipairs(M.session_projects) do
      M.session_projects[i] = {
        path = v,
        name = vim.fn.fnamemodify(v, ':p:h:h:t') .. '/' .. vim.fn.fnamemodify(v, ':p:h:t'),
      }
    end
  end

  M.write_history()
  M.read_history()
end

---@param project string
---@param name string
function M.rename_project(project, name)
  if M.legacy then
    return
  end

  Util.validate({
    project = { project, { 'string' } },
    name = { name, { 'string' } },
  })

  local renamed = false
  local recent_i = 0
  for i, proj in ipairs(M.recent_projects) do
    ---@cast proj ProjectHistoryEntry
    if proj.path == project then
      recent_i = i
      break
    end
  end
  if recent_i ~= 0 then
    M.recent_projects[recent_i].name = name
    renamed = true
  end

  local session_i = 0
  for i, proj in ipairs(M.session_projects) do
    ---@cast proj ProjectHistoryEntry
    if proj.path == project then
      session_i = i
      break
    end
  end
  if session_i ~= 0 then
    M.session_projects[session_i].name = name
    renamed = true
  end

  if renamed then
    -- TODO: Include old name and/or more information
    vim.notify(('(%s.rename_project): Changed name successfully!'):format(MODSTR), INFO)
    Log.debug(('(%s.rename_project): Changed name successfully!'):format(MODSTR))

    M.write_history()
  end
end

---@param force? boolean
function M.clear_historyfile(force)
  Util.validate({ force = { force, { 'boolean', 'nil' }, true } })
  if force == nil then
    force = false
  end

  if vim.g.project_historyfile_cleared == 1 then
    Log.info(('(%s.clear_historyfile): Already cleared. Aborting.'):format(MODSTR))
    return
  end
  if not force then
    if
      vim.fn.confirm('Are you sure you want to clear the project history?', '&Yes\n&No', 2) ~= 1
    then
      Log.info(('(%s.clear_historyfile): Aborting.'):format(MODSTR))
      return
    end
  end

  local fd = Path.open_file(Path.historyfile, 'w', tonumber('644', 8))
  if not fd then
    Log.error(('(%s.clear_historyfile): Unable to clear history file!'):format(MODSTR))
    vim.notify('(project.nvim): Unable to clear history file!', ERROR)
    return
  end

  local success = uv.fs_write(fd, { '[', ']' })
  uv.fs_close(fd)
  if not success then
    Log.error(('(%s.clear_historyfile): Unable to clear history file!'):format(MODSTR))
    vim.notify('(project.nvim): Unable to clear history file!', ERROR)
    return
  end

  Log.warn(('(%s.clear_historyfile): History file cleared successfully.'):format(MODSTR))
  vim.notify('(project.nvim): History file cleared successfully', WARN)

  M.recent_projects = {}
  M.session_projects = {}
  vim.g.project_historyfile_cleared = 1
end

---@param mode uv.fs_open.flags
---@return integer|nil fd
---@return uv.fs_stat.result|nil stat
function M.open_history(mode)
  Util.validate({ mode = { mode, { 'string', 'number' } } })

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
  if Util.is_type('string', mode) and not vim.list_contains(allowed_flags, mode) then
    Log.error(('(%s.open_history): Invalid flag `%s`!'):format(MODSTR, mode))
    error(('(%s.open_history): Invalid flag `%s`!'):format(MODSTR, mode))
  end

  Path.create_path()

  local dir_stat = uv.fs_stat(Path.projectpath)
  if not dir_stat then
    Log.error(('(%s.open_history): History directory unavailable!'):format(MODSTR))
    error(('(%s.open_history): History directory unavailable!'):format(MODSTR), ERROR)
  end

  if not Path.exists(Path.historyfile) then
    if vim.fn.writefile({ '[', ']' }, Path.historyfile) == -1 then
      Log.error(('(%s.open_history): History file unavailable!'):format(MODSTR))
      error(('(%s.open_history): History file unavailable!'):format(MODSTR), ERROR)
    end
  end

  return Path.open_file(Path.historyfile, mode)
end

---@param path string
---@param ind? integer|string|nil
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
    ind = math.floor(tonumber(ind, 10))
  end

  if vim.g.project_setup ~= 1 then
    return
  end

  local spc = nil ---@type string|nil
  if ind >= 1 then
    spc = (' '):rep(
      not vim.list_contains({ math.floor(ind), math.ceil(ind) }, ind) and math.floor(ind) or ind
    )
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

  path = vim.fn.fnamemodify(path, ':p')
  if path:sub(-5) ~= '.json' and not force_name then
    path = ('%s.json'):format(path)
  end

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
      if
        vim.fn.confirm(
          ('File exists! Do you really want to export to it?'):format(path),
          '&Yes\n&No',
          2
        ) ~= 1
      then
        Log.info('(%s.delete_project): Aborting project export.')
        return
      end
    end
  end

  M.write_history()

  if not Path.exists(path) then
    if Util.dir_exists(path) then
      return
    end
    if vim.fn.writefile({}, path) ~= 0 then
      error('File restricted!', ERROR)
    end
  end

  local fd = Path.open_file(path, 'w')
  if not fd then
    Log.error(('(%s.export_history_json): File restricted! `%s`'):format(MODSTR, path))
    error(('(%s.export_history_json): File restricted! `%s`'):format(MODSTR, path), ERROR)
  end

  local data = vim.json.encode(Util.reverse(M.get_recent_projects()), { indent = spc })

  uv.fs_write(fd, data)
  uv.fs_close(fd)

  vim.notify(('Exported history to `%s`'):format(vim.fn.fnamemodify(path, ':~')), INFO, {
    title = 'project.nvim',
  })
end

---@param path string
---@param force_name? boolean
function M.import_history_json(path, force_name)
  Util.validate({
    path = { path, { 'string' } },
    force_name = { force_name, { 'boolean', 'nil' }, true },
  })
  if force_name == nil then
    force_name = false
  end

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

  local fd, stat = Path.open_file(path, 'r')
  if not fd then
    Log.error(('(%s.import_history_json): File restricted! `%s`'):format(MODSTR, path))
    error(('(%s.import_history_json): File restricted! `%s`'):format(MODSTR, path), ERROR)
  end
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

  M.recent_projects = Util.reverse(hist)
  M.write_history()

  vim.notify(('Imported history from `%s`'):format(vim.fn.fnamemodify(path, ':~')), INFO, {
    title = 'project.nvim',
  })
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

  local i = 1
  M.is_legacy(M.session_projects)
  while i < #M.session_projects do
    local recent = M.legacy and M.session_projects[i] or M.session_projects[i].path
    if recent == session then
      table.remove(M.session_projects, i)
      found = true
      i = i - 1
    else
      i = i + 1
    end
  end
  return found
end

---Remove a project from recent projects.
--- ---
---@param project string
---@return boolean found
function M.remove_recent(project)
  Util.validate({ project = { project, { 'string' } } })

  local found, i = false, 1 ---@type boolean, integer
  M.is_legacy(M.recent_projects)
  while i <= #M.recent_projects do
    local recent = M.legacy and M.recent_projects[i] or M.recent_projects[i].path
    if recent == project then
      table.remove(M.recent_projects, i)
      found = true
      i = i - 1
    else
      i = i + 1
    end
  end
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
    Log.error(('(%s.delete_project): `recent_projects` is nil! Aborting.'):format(MODSTR))
    vim.notify(('(%s.delete_project): `recent_projects` is nil! Aborting.'):format(MODSTR))
    return
  end

  ---@cast project string|Project.ActionEntry
  local proj = type(project) == 'string' and project or project.value
  if prompt then
    if vim.fn.confirm(("Delete '%s' from project list?"):format(proj), '&Yes\n&No', 2) ~= 1 then
      Log.info(('(%s.delete_project): Aborting project deletion.'):format(MODSTR))
      return
    end
  end

  local found = M.remove_recent(proj)
  found = M.remove_session(proj, found)

  if found then
    Log.info(('(%s.delete_project): Deleting project `%s`.'):format(MODSTR, proj))
    vim.notify(('(%s.delete_project): Deleting project `%s`.'):format(MODSTR, proj), INFO)
    M.write_history()
  end
end

---Splits data into table.
--- ---
---@param history_data string
---@param name_data? string[]
function M.deserialize_history(history_data, name_data)
  Util.validate({
    history_data = { history_data, { 'string' } },
    name_data = { name_data, { 'table', 'nil' }, true },
  })
  name_data = (name_data and not vim.tbl_isempty(name_data)) and name_data or nil

  local projects = {} ---@type string[]|ProjectHistoryEntry[]
  local i = 1
  for s in history_data:gmatch('[^\r\n]+') do
    local entry = name_data and {} or '' ---@type string|ProjectHistoryEntry
    if not Path.is_excluded(s) and Path.exists(s) then
      if not name_data then
        ---@cast entry string
        entry = s
      else
        ---@cast entry ProjectHistoryEntry
        entry.path = s
        entry.name = name_data[i]
      end
      table.insert(projects, entry)
    end

    i = i + 1
  end
  M.recent_projects = Util.delete_duplicates(projects)
end

---Only runs once.
--- ---
function M.setup_watch()
  if M.has_watch_setup then
    return
  end

  local event = uv.new_fs_event()
  if not event then
    return
  end
  event:start(Path.projectpath, {}, function(err, _, events)
    if err or not events.change then
      return
    end
    M.recent_projects = nil
    M.read_history()
  end)
  M.has_watch_setup = true
end

function M.read_history()
  local fd, stat = M.open_history('r')
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

  M.setup_watch()

  if stat.size == 0 and M.session_projects then
    M.write_history()
    return
  end

  ---@type boolean, string[]|ProjectHistoryEntry[]|nil
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

  local data_str, name_list = '', {} ---@type string, string[]
  M.is_legacy(data)
  for _, v in ipairs(data) do
    data_str = ('%s%s%s'):format(data_str, data_str == '' and '' or '\n', M.legacy and v or v.path)

    if not M.legacy then
      ---@cast v ProjectHistoryEntry
      table.insert(name_list, v.name)
    end
  end

  M.deserialize_history(data_str, name_list)
end

---@overload fun(): recents: ProjectHistoryEntry[]
---@overload fun(paths_only?: false, tilde?: boolean): recents: ProjectHistoryEntry[]
---@overload fun(paths_only: true, tilde?: boolean): recents: string[]
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

  local tbl = {} ---@type string[]|ProjectHistoryEntry[]
  if M.recent_projects then
    vim.list_extend(tbl, M.recent_projects)
    vim.list_extend(tbl, M.session_projects)
  else
    tbl = M.session_projects
  end
  tbl = Util.delete_duplicates(tbl)

  local idx, removed = 1, false
  M.is_legacy(tbl)
  while idx <= #tbl do
    local v = Util.rstrip('/', M.legacy and tbl[idx] or tbl[idx].path)
    if not Path.exists(v) or Path.is_excluded(v) then
      table.remove(tbl, idx)
      removed = true
      idx = idx - 1
    end
    idx = idx + 1
  end

  if removed then
    M.write_history()
  end

  local recents = {} ---@type string[]|ProjectHistoryEntry[]
  for i, v in ipairs(tbl) do
    local dir = M.legacy and v or v.path
    if Util.dir_exists(dir) then
      dir = tilde and vim.fn.fnamemodify(dir, ':~') or dir
      table.insert(recents, (M.legacy or paths_only) and dir or { path = dir, name = tbl[i].name })
    end
  end
  return Util.dedup(recents, M.legacy and nil or 'name')
end

---Write projects to history file.
--- ---
---@param path? string
function M.write_history(path)
  Util.validate({ path = { path, { 'string', 'nil' }, true } })
  path = Util.rstrip('/', vim.fn.fnamemodify(path or Path.historyfile, ':p'))

  if not Path.exists(path) then
    local write_res = vim.fn.writefile({ '[', ']' }, path)
    if write_res ~= 0 then
      Log.error(('(%s.write_history): History file unavailable!'):format(MODSTR))
      error(('(%s.write_history): History file unavailable!'):format(MODSTR), ERROR)
    end
  end

  local historysize = require('project.config').options.history.size or 100
  M.historysize = historysize > 0 and historysize or 100

  local file_history = {} ---@type string[]|ProjectHistoryEntry[]
  local fd, stat ---@type integer|nil, uv.fs_stat.result|nil
  if path == Path.historyfile then
    fd, stat = M.open_history('r')
  else
    fd, stat = Path.open_file(path, 'r')
  end
  if fd and stat then
    local data = uv.fs_read(fd, stat.size)
    uv.fs_close(fd)
    if data then
      file_history = vim.json.decode(data) --[[@as string[]|ProjectHistoryEntry[]\]]
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

  local tbl_out = vim.deepcopy(file_history)
  if M.historysize and M.historysize > 0 then
    tbl_out = #res > M.historysize and vim.list_slice(res, #res - M.historysize, #res) or res
  end

  if vim.tbl_isempty(tbl_out) then
    uv.fs_close(fd)
    Log.error(('(%s.write_history): No data available to write!'):format(MODSTR))
    vim.notify(('(%s.write_history): No data available to write!'):format(MODSTR), WARN)
    return
  end

  if path == Path.historyfile then
    fd = M.open_history('w')
  else
    fd = Path.open_file(path, 'w')
  end
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

  uv.fs_write(fd, out)
  uv.fs_close(fd)
end

---@param data string[]|ProjectHistoryEntry[]
---@return boolean legacy
function M.is_legacy(data)
  Util.validate({ data = { data, { 'table' } } })

  local is_legacy = nil ---@type boolean|nil
  for _, entry in ipairs(data) do
    if is_legacy == nil then
      is_legacy = Util.is_type('string', entry)
    end

    if is_legacy then
      ---@cast entry string
      Util.validate({ entry = { entry, { 'string' } } })
    else
      ---@cast entry ProjectHistoryEntry
      Util.validate({
        entry = { entry, { 'table' } },
        ['entry.path'] = { entry.path, { 'string' } },
        ['entry.name'] = { entry.name, { 'string' } },
      })
    end
  end

  if is_legacy and vim.g.project_migration_notified ~= 1 then
    vim.g.project_migration_notified = 1
    vim.notify(
      [[project.nvim - Your history needs to be migrated to the new spec!
To migrate simply run `:ProjectHistory migrate` in your cmdline.

If you encounter any bugs please raise an issue and it will be dealt with ASAP.]],
      WARN
    )
  end

  M.legacy = is_legacy
  return is_legacy
end

---@param search 'session'|'recent'
---@param project string
---@param field 'path'|'name'
---@return string|nil entry_field
function M.find_entry(search, project, field)
  Util.validate({
    search = { search, { 'string' } },
    project = { project, { 'string' } },
    field = { field, { 'string' } },
  })
  if not vim.list_contains({ 'recent', 'session' }, search) then
    return
  end
  if not (vim.list_contains({ 'path', 'name' }, field) and not M.legacy) then
    return
  end

  local tbl = search == 'session' and M.session_projects or M.recent_projects --[[@as ProjectHistoryEntry[]\]]
  for _, v in ipairs(tbl) do
    if v.path == Util.rstrip('/', vim.fn.fnamemodify(project, ':p')) or v.name == project then
      return v[field]
    end
  end
end

function M.open_win()
  if not Path.historyfile then
    return
  end
  if not Path.exists(Path.historyfile) then
    Log.error(('(%s.open_win): Bad historyfile path!'):format(MODSTR))
    error(('(%s.open_win): Bad historyfile path!'):format(MODSTR), ERROR)
  end
  if M.window then
    return
  end

  local fd, stat = M.open_history('r')
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

  ---@type boolean, string[]|ProjectHistoryEntry[]|nil
  local ok, data = pcall(vim.json.decode, uv.fs_read(fd, stat.size))
  if not (ok and data) then
    uv.fs_close(fd)
    return
  end

  vim.cmd.tabnew()
  vim.schedule(function()
    M.window = {
      bufnr = vim.api.nvim_get_current_buf(),
      win = vim.api.nvim_get_current_win(),
      tab = vim.api.nvim_get_current_tabpage(),
    }

    local lines = {} ---@type string[]
    M.is_legacy(data)
    if M.legacy then
      ---@cast data string[]
      lines = vim.deepcopy(data)
    else
      ---@cast data ProjectHistoryEntry[]
      for _, entry in ipairs(data) do
        table.insert(lines, entry.name)
      end
    end

    vim.api.nvim_buf_set_lines(M.window.bufnr, 0, 1, true, Util.reverse(lines))
    vim.api.nvim_buf_set_name(M.window.bufnr, 'Project History')

    Util.optset('signcolumn', 'no', 'win', M.window.win)
    Util.optset('list', false, 'win', M.window.win)
    Util.optset('number', false, 'win', M.window.win)
    Util.optset('wrap', false, 'win', M.window.win)
    Util.optset('colorcolumn', '', 'win', M.window.win)
    Util.optset('filetype', '', 'buf', M.window.bufnr)
    Util.optset('fileencoding', 'utf-8', 'buf', M.window.bufnr)
    Util.optset('buftype', 'nowrite', 'buf', M.window.bufnr)
    Util.optset('modifiable', false, 'buf', M.window.bufnr)

    vim.keymap.set('n', 'q', M.close_win, {
      buffer = M.window.bufnr,
      noremap = true,
      silent = true,
    })
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
