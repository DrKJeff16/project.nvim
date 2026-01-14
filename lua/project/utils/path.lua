local MODSTR = 'project.utils.path'
local uv = vim.uv or vim.loop
local Util = require('project.utils.util')

---@class Project.Utils.Path
---The directory where the project dir will be saved.
--- ---
---@field datapath? string
---The directory where the project history will be saved.
--- ---
---@field projectpath? string
---The project history file.
--- ---
---@field historyfile? string
local Path = {}

Path.last_dir_cache = ''
Path.curr_dir_cache = {} ---@type string[]
Path.exists = require('project.utils.util').path_exists

---@param dir string
---@return boolean excluded
function Path.is_excluded(dir)
  Util.validate({ dir = { dir, { 'string' } } })

  local exclude_dirs = require('project.config').options.exclude_dirs
  for _, excluded in ipairs(exclude_dirs) do
    if dir:match(excluded) ~= nil then
      return true
    end
  end
  return false
end

---@param dir string
---@param identifier string
function Path.is(dir, identifier)
  Util.validate({
    dir = { dir, { 'string' } },
    identifier = { identifier, { 'string' } },
  })

  return dir:match('.*/(.*)') == identifier
end

---@param path_str string
---@return string parent
function Path.get_parent(path_str)
  Util.validate({ path_str = { path_str, { 'string' } } })

  local parent = path_str:match('^(.*)/') ---@type string
  return parent ~= '' and parent or '/'
end

---@param file_dir string
function Path.get_files(file_dir)
  Util.validate({ file_dir = { file_dir, { 'string' } } })

  Path.last_dir_cache = file_dir
  Path.curr_dir_cache = {}
  local dir = uv.fs_scandir(file_dir)
  if not dir then
    return
  end
  while true do
    local file = uv.fs_scandir_next(dir)
    if not file then
      return
    end
    table.insert(Path.curr_dir_cache, file)
  end
end

---@param dir string
---@param identifier string
---@return boolean has
function Path.has(dir, identifier)
  Util.validate({
    dir = { dir, { 'string' } },
    identifier = { identifier, { 'string' } },
  })

  local globtopattern = require('project.utils.globtopattern').globtopattern
  if Path.last_dir_cache ~= dir then
    Path.get_files(dir)
  end

  local pattern = globtopattern(identifier)
  for _, file in ipairs(Path.curr_dir_cache) do
    if file:match(pattern) ~= nil then
      return true
    end
  end
  return false
end

---@param dir string
---@param identifier string
---@return boolean is_sub
function Path.sub(dir, identifier)
  Util.validate({
    dir = { dir, { 'string' } },
    identifier = { identifier, { 'string' } },
  })

  local path_str = Path.get_parent(dir)
  local current
  while true do
    if Path.is(path_str, identifier) then
      return true
    end
    current, path_str = path_str, Path.get_parent(path_str)
    if current == path_str then
      return false
    end
  end
end

---@param dir string
---@param identifier string
---@return boolean is_child
function Path.child(dir, identifier)
  Util.validate({
    dir = { dir, { 'string' } },
    identifier = { identifier, { 'string' } },
  })

  return Path.is(Path.get_parent(dir), identifier)
end

---@param dir string
---@param pattern string
---@return boolean matches
function Path.match(dir, pattern)
  Util.validate({
    dir = { dir, { 'string' } },
    pattern = { pattern, { 'string' } },
  })

  local SWITCH = {
    ['='] = Path.is,
    ['^'] = Path.sub,
    ['>'] = Path.child,
  }
  local first_char = pattern:sub(1, 1)
  for char, case in pairs(SWITCH) do
    if first_char == char then
      return case(dir, pattern:sub(2))
    end
  end
  return Path.has(dir, pattern)
end

---@param path string
---@overload fun()
function Path.create_path(path)
  Util.validate({ path = { path, { 'string', 'nil' }, true } })
  path = path or Path.projectpath

  if not Path.exists(path) then
    vim.schedule(function()
      require('project.utils.log').debug(
        ('(%s.create_path): Creating directory `%s`.'):format(MODSTR, path)
      )
    end)
    uv.fs_mkdir(path, tonumber('755', 8))
  end
end

---@param dir string
---@return string|nil dir
---@return string|nil pattern
function Path.root_included(dir)
  Util.validate({ dir = { dir, { 'string' } } })

  local Config = require('project.config')
  while true do ---Breadth-First search
    for _, pattern in ipairs(Config.options.patterns) do
      local excluded = false
      if pattern:sub(1, 1) == '!' then
        excluded, pattern = true, pattern:sub(2)
      end
      if Path.match(dir, pattern) then
        if not excluded then
          return dir, 'pattern ' .. pattern
        end
        break
      end
    end
    local parent = Path.get_parent(dir)
    if not parent or parent == dir then
      return
    end
    dir = parent
  end
end

---@param datapath string
function Path.init(datapath)
  Util.validate({ datapath = { datapath, { 'string' } } })

  datapath = Path.exists(datapath) and datapath or vim.fn.stdpath('data')
  Path.datapath = datapath
  Path.projectpath = ('%s/project_nvim'):format(Path.datapath)
  Path.historyfile = ('%s/project_history'):format(Path.projectpath)
end

return Path
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
