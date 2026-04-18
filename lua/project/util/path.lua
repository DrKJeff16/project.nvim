local MODSTR = 'project.util.path'
local ERROR = vim.log.levels.ERROR
local uv = vim.uv or vim.loop
local Util = require('project.util')
local Config = require('project.config')

---@class Project.Util.Path
---@field private curr_dir_cache string[]
---The directory where the project dir will be saved.
--- ---
---@field datapath? string
---The project history file.
--- ---
---@field historyfile? string
---@field private last_dir_cache string
---The directory where the project history will be saved.
--- ---
---@field projectpath? string
local M = {}

M.last_dir_cache = ''
M.curr_dir_cache = {}
M.exists = Util.path_exists

---@param path string
---@param flags uv.fs_open.flags
---@param mode? integer
---@return integer|nil fd
---@return uv.fs_stat.result|nil stat
function M.open_file(path, flags, mode)
  Util.validate({
    path = { path, { 'string' } },
    flags = { flags, { 'string', 'number' } },
    mode = { mode, { 'number', 'nil' }, true },
  })
  mode = (mode and Util.is_int(mode)) and mode or tonumber('644', 8)
  if not M.exists(path) then
    return
  end

  local stat = uv.fs_stat(path)
  local fd = uv.fs_open(path, flags, mode)
  return fd, stat
end

---Check if given directory is owned by the user running Nvim.
---
---If running under Windows, this will return `true` regardless.
--- ---
---@param dir string
---@return boolean verified
---@nodiscard
function M.verify_owner(dir)
  Util.validate({ dir = { dir, { 'string' } } })

  local Log = require('project.util.log')
  if Util.is_windows() then
    Log.info(('(%s.verify_owner): Running on a Windows system. Aborting.'):format(MODSTR))
    return true
  end

  local stat = uv.fs_stat(dir)
  if not stat then
    Log.error(("(%s.verify_owner): Directory can't be accessed!"):format(MODSTR))
    vim.notify(("(%s.verify_owner): Directory can't be accessed!"):format(MODSTR), ERROR)
    return false
  end
  return stat.uid == uv.getuid()
end

---@param dir string
---@return boolean excluded
function M.is_excluded(dir)
  Util.validate({ dir = { dir, { 'string' } } })

  local exclude_dirs = Config.options.exclude_dirs
  for _, excluded in ipairs(exclude_dirs) do
    if dir:match(excluded) then
      return true
    end
  end
  return false
end

---@param dir string
---@param identifier string
---@return boolean is
function M.is(dir, identifier)
  Util.validate({
    dir = { dir, { 'string' } },
    identifier = { identifier, { 'string' } },
  })

  return dir:match('.*/(.*)') == identifier
end

---@param path_str string
---@return string parent
function M.get_parent(path_str)
  Util.validate({ path_str = { path_str, { 'string' } } })

  local parent = path_str:match('^(.*)/') ---@type string
  return parent ~= '' and parent or '/'
end

---@param file_dir string
function M.get_files(file_dir)
  Util.validate({ file_dir = { file_dir, { 'string' } } })

  M.last_dir_cache = file_dir
  M.curr_dir_cache = {}
  local dir = uv.fs_scandir(file_dir)
  if not dir then
    return
  end
  while true do
    local file = uv.fs_scandir_next(dir)
    if not file then
      return
    end
    table.insert(M.curr_dir_cache, file)
  end
end

---@param dir string
---@param identifier string
---@return boolean has
function M.has(dir, identifier)
  Util.validate({
    dir = { dir, { 'string' } },
    identifier = { identifier, { 'string' } },
  })

  if M.last_dir_cache ~= dir then
    M.get_files(dir)
  end

  local pattern = require('project.util.globtopattern').globtopattern(identifier)
  for _, file in ipairs(M.curr_dir_cache) do
    if file:match(pattern) then
      return true
    end
  end
  return false
end

---@param dir string
---@param identifier string
---@return boolean is_sub
function M.sub(dir, identifier)
  Util.validate({
    dir = { dir, { 'string' } },
    identifier = { identifier, { 'string' } },
  })

  local path_str = M.get_parent(dir)
  local current
  while true do
    if M.is(path_str, identifier) then
      return true
    end
    current, path_str = path_str, M.get_parent(path_str)
    if current == path_str then
      return false
    end
  end
end

---@param dir string
---@param identifier string
---@return boolean is_child
function M.child(dir, identifier)
  Util.validate({
    dir = { dir, { 'string' } },
    identifier = { identifier, { 'string' } },
  })

  return M.is(M.get_parent(dir), identifier)
end

---@param dir string
---@param pattern string
---@return boolean matches
function M.match(dir, pattern)
  Util.validate({
    dir = { dir, { 'string' } },
    pattern = { pattern, { 'string' } },
  })

  local SWITCH = {
    ['='] = M.is,
    ['^'] = M.sub,
    ['>'] = M.child,
  }
  local first_char = pattern:sub(1, 1)
  for char, case in pairs(SWITCH) do
    if first_char == char then
      return case(dir, pattern:sub(2))
    end
  end
  return M.has(dir, pattern)
end

---@param path string|nil
function M.create_path(path)
  Util.validate({ path = { path, { 'string', 'nil' }, true } })
  path = path or M.projectpath --[[@as string]]

  if not M.exists(path) then
    require('project.util.log').debug(
      ('(%s.create_path): Creating directory `%s`.'):format(MODSTR, path)
    )
    uv.fs_mkdir(path, tonumber('755', 8))
  end
end

---@param dir string
---@return string|nil dir
---@return string|nil pattern
function M.root_included(dir)
  Util.validate({ dir = { dir, { 'string' } } })

  while true do ---Breadth-First search
    for _, pattern in ipairs(Config.options.patterns) do
      local excluded = false
      if pattern:sub(1, 1) == '!' then
        excluded, pattern = true, pattern:sub(2)
      end
      if M.match(dir, pattern) then
        if not excluded then
          return dir, ('pattern %s'):format(pattern)
        end
        break
      end
    end
    local parent = M.get_parent(dir)
    if not parent or parent == dir then
      return
    end

    --- CREDITS: @pidgeon777 (https://github.com/ahmedkhalf/project.nvim/issues/187)
    if Util.is_windows() and parent:match('^%a:$') then
      return
    end
    dir = parent
  end
end

---@param save_dir string
---@param save_file string
function M.init(save_dir, save_file)
  local Defaults = require('project.config.defaults')
  Util.validate({
    save_dir = { save_dir, { 'string' } },
    save_file = { save_file, { 'string' } },
  })

  M.datapath = save_dir
  if not (vim.fn.mkdir(M.datapath, 'p') == 1 or M.exists(M.datapath)) then
    M.datapath = Defaults.history.save_dir
    if not (vim.fn.mkdir(M.datapath, 'p') == 1 or M.exists(M.datapath)) then
      error('(%s.init): Unable to create history directory!', ERROR)
    end
  end

  M.projectpath = vim.fs.joinpath(M.datapath, 'project_nvim')
  if not (M.exists(M.projectpath) or vim.fn.mkdir(M.projectpath, 'p') == 1) then
    error('(%s.init): Unable to create history subdirectory!', ERROR)
  end

  M.historyfile = vim.fs.joinpath(M.projectpath, save_file)
  if not M.exists(M.historyfile) then
    local fd = uv.fs_open(M.historyfile, 'w', tonumber('644', 8))
    if not fd then
      error('(%s.init): Unable to create history file!', ERROR)
    end

    uv.fs_write(fd, '[]')
    uv.fs_close(fd)
  end
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
