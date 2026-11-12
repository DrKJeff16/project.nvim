local last_dir_cache, curr_dir_cache = '', {} ---@type string, string[]

local Util = require('project.util')

---@generic T: table, F
---@param t T
---@param k any
---@param fallback F
---@return F fallback
local function get(t, k, fallback)
  return Util.get(t, k, function()
    return Util.rawset(t, k, fallback)
  end, true)
end

---@param path_str string
---@return string parent
local function get_parent(path_str)
  Util.validate({ path_str = { path_str, { 'string' } } })

  local parent = path_str:match('^(.*)/') --[[@as string]]
  return parent ~= '' and parent or '/'
end

---@param file_dir string
local function get_files(file_dir)
  Util.validate({ file_dir = { file_dir, { 'string' } } })

  last_dir_cache, curr_dir_cache = file_dir, {}
  local dir = vim.uv.fs_scandir(file_dir)
  if dir then
    while true do
      local file = vim.uv.fs_scandir_next(dir)
      if not file then
        break
      end
      table.insert(curr_dir_cache, file)
    end
  end
end

---@param dir string
---@param identifier string
---@return boolean is
local function is(dir, identifier)
  Util.validate({
    dir = { dir, { 'string' } },
    identifier = { identifier, { 'string' } },
  })

  return dir:match('.*/(.*)') == identifier
end

---@param dir string
---@param identifier string
---@return boolean has
---@nodiscard
local function has(dir, identifier)
  Util.validate({
    dir = { dir, { 'string' } },
    identifier = { identifier, { 'string' } },
  })

  if last_dir_cache ~= dir then
    get_files(dir)
  end

  local pattern, result = Util.globtopattern(identifier), false
  for _, file in ipairs(curr_dir_cache) do
    if file:match(pattern) then
      result = true
      break
    end
  end
  return result
end

---@param dir string
---@param identifier string
---@return boolean is_sub
---@nodiscard
local function sub(dir, identifier)
  Util.validate({
    dir = { dir, { 'string' } },
    identifier = { identifier, { 'string' } },
  })

  local path_str = get_parent(dir)
  local current ---@type string
  while true do
    if is(path_str, identifier) then
      return true
    end

    current, path_str = path_str, get_parent(path_str)
    if current == path_str then
      return false
    end
  end
end

---@param dir string
---@param identifier string
---@return boolean is_child
---@nodiscard
local function child(dir, identifier)
  Util.validate({
    dir = { dir, { 'string' } },
    identifier = { identifier, { 'string' } },
  })

  return is(get_parent(dir), identifier)
end

---@param dir string
---@param pattern string
---@return boolean matches
---@nodiscard
local function match(dir, pattern)
  Util.validate({
    dir = { dir, { 'string' } },
    pattern = { pattern, { 'string' } },
  })

  local SWITCH, first_char = { ['='] = is, ['>'] = child, ['^'] = sub }, pattern:sub(1, 1)
  for char, case in pairs(SWITCH) do
    if first_char == char then
      return case(dir, pattern:sub(2))
    end
  end
  return has(dir, pattern)
end

---@class Project.Util.Path
---The directory where the project data will be saved at.
--- ---
---@field datapath? string
---@field exists fun(path_or_paths: string[]|string): exists: boolean
---The project history file.
--- ---
---@field historyfile? string
---@field is_hidden fun(path: string): hidden: boolean
---@field join fun(...: string): joined_path: string
---The directory where the project history will be saved.
--- ---
---@field projectpath? string
local M = {}

setmetatable(M, {
  __index = function(self, k)
    local raw = Util.get(self, k) or nil
    if raw ~= nil then
      return raw
    end

    if type(k) ~= 'string' then
      return
    end

    ---@cast k string
    if k == 'exists' then
      return get(self, k, Util.path_exists)
    end
    if k == 'is_hidden' then
      return get(self, k, Util.is_hidden)
    end
    if k == 'join' then
      return get(self, k, vim.fs.joinpath)
    end
  end,
})

---@param mode string
---@return integer|nil|? mode_num
function M.open_mode(mode)
  Util.validate({ mode = { mode, { 'string' } } })

  if mode ~= '' and mode:len() == 3 then
    for _, c in ipairs(vim.split(mode, '', { trimempty = false })) do
      local ok, cnum = pcall(tonumber, c, 10) ---@type boolean, integer|nil|?
      if not (ok and cnum) or cnum < 0 or cnum > 7 then
        return
      end
    end
    return tonumber(mode, 8)
  end
end

---@param path string
---@param flags uv.fs_open.flags
---@param mode integer
---@return integer|nil|? fd
---@return uv.fs_stat.result|nil|? stat
---@overload fun(path: string, flags: uv.fs_open.flags): fd: integer|nil|?, stat: uv.fs_stat.result|nil|?
function M.open_file(path, flags, mode)
  Util.validate({
    path = { path, { 'string' } },
    flags = { flags, { 'string', 'number' } },
    mode = { mode, { 'number', 'nil' }, true },
  })

  if M.exists(path) then
    return (vim.uv.fs_open(path, flags, (mode and Util.is_int(mode)) and mode or M.open_mode('644'))),
      (vim.uv.fs_stat(path))
  end
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

  local res = true ---@type boolean
  if Util.is_windows() and vim.g.project_verify_windows_logged ~= 1 then
    Util.log.info('(project.util.path.verify_owner): Running on a Windows system, aborting verification')
    vim.g.project_verify_windows_logged = 1
  elseif not Util.is_windows() then
    res = assert(vim.uv.fs_stat(dir), 'Directory cannot be accessed').uid == vim.uv.getuid()
  end
  return res
end

---@param dir string
---@return boolean excluded
---@nodiscard
function M.is_excluded(dir)
  Util.validate({ dir = { dir, { 'string' } } })

  local res = false
  for _, excluded in ipairs(require('project.config').get().exclude_dirs) do
    if dir:match(excluded) then
      res = true
      break
    end
  end
  return res
end

---@param path string
---@overload fun()
function M.create_path(path)
  Util.validate({ path = { path, { 'string', 'nil' }, true } })
  path = path or M.projectpath --[[@as string]]

  if not M.exists(path) then
    Util.log.debug(('(project.util.path.create_path): Attempting to create directory: `%s`'):format(path))
    assert(pcall(M.mkdir, path), ('Unable to create diretory: `%s`'):format(path))
  end
end

---@param dir string
---@return string|nil|? dir
---@return string|nil|? pattern
---@nodiscard
function M.root_included(dir)
  Util.validate({ dir = { dir, { 'string' } } })

  local config = require('project.config').get()
  while true do ---Breadth-First search
    for _, pattern in ipairs(config.patterns) do
      local excluded = false
      if pattern:sub(1, 1) == '!' then
        excluded, pattern = true, pattern:sub(2)
      end
      for _, custom in ipairs(config.custom_projects) do
        if dir == custom.path then
          return dir, 'custom'
        end
      end

      local matches = match(dir, pattern)
      if not matches then
        break
      end
      if not excluded then
        return dir, ('pattern %s'):format(pattern)
      end
    end

    --- CREDITS: @pidgeon777 (https://github.com/ahmedkhalf/project.nvim/issues/187)
    local parent = get_parent(dir)
    if parent == dir or (Util.is_windows() and parent:match('^%a:$') ~= nil) then
      break
    end
    dir = parent
  end
end

---@param path string
---@param mode integer
---@param parents boolean
---@overload fun(path: string)
---@overload fun(path: string, mode: integer)
---@overload fun(path: string, mode: nil, parents: boolean)
function M.mkdir(path, mode, parents)
  Util.validate({
    path = { path, { 'string' } },
    mode = { mode, { 'number', 'nil' }, true },
    parents = { parents, { 'boolean', 'nil' }, true },
  })
  if parents == nil then
    parents = true
  end

  if Util.vim_has('nvim-0.13') and vim.fs and vim.fs.mkdir then
    vim.fs.mkdir(path, { mode = mode or M.open_mode('755') or tonumber('755', 8), parents = parents })
  else
    vim.fn.mkdir(path, parents and 'p' or nil)
  end
end

---@param save_dir string
---@param save_file string
function M.setup(save_dir, save_file)
  Util.validate({
    save_dir = { save_dir, { 'string' } },
    save_file = { save_file, { 'string' } },
  })

  if not (M.exists(save_dir) or pcall(M.mkdir, save_dir)) then
    save_dir = require('project.config.defaults'):_get_no_mt().history.save_dir
    if not M.exists(save_dir) then
      assert(pcall(M.mkdir, save_dir), 'Unable to create history directory')
    end
  end

  M.datapath, M.projectpath = save_dir, vim.fs.joinpath(save_dir, 'project_nvim')
  if not M.exists(M.projectpath) then
    assert(pcall(M.mkdir, M.projectpath), 'Unable to create history subdirectories')
  end

  M.historyfile = vim.fs.joinpath(M.projectpath, save_file)
  if not M.exists(M.historyfile) then
    local fd = assert(vim.uv.fs_open(M.historyfile, 'w', M.open_mode('644')), 'Unable to create history file')
    assert(vim.uv.fs_write(fd, { '[', ']' }), 'Unable to write contents to empty history file')
    assert(vim.uv.fs_close(fd), 'Unable to close file descriptor for history file')
  end
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
