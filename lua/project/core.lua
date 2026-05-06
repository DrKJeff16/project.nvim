---For newcommers, in the original `project.nvim` this file was `project.lua`.
---I decided to make this an API file instead to avoid any confusions with naming,
---e.g. `require('project_nvim.project')`.

---@module 'project._meta'

local MODSTR = 'project.core'
local ERROR = vim.log.levels.ERROR
local INFO = vim.log.levels.INFO
local uv = vim.uv or vim.loop
local Config = require('project.config')
local Path = require('project.util.path')
local Util = require('project.util')
local History = require('project.util.history')
local Log = require('project.util.log')
local in_list = vim.list_contains

---The `project.nvim` API module.
--- ---
---@class Project.Core
---@field public current_method string|nil
---@field public current_project string|nil
---@field public last_project string|nil
local M = {}

---@class ProjectRootSwitch
local SWITCH = {}

---@param bufnr? integer
---@return boolean success
---@return string|nil root
---@return string|nil method
---@nodiscard
function SWITCH.lsp(bufnr)
  Util.validate({ bufnr = { bufnr, { 'number', 'nil' }, true } })
  bufnr = (bufnr and Util.is_int(bufnr, bufnr >= 0)) and bufnr or vim.api.nvim_get_current_buf()

  local root, lsp_name = M.find_lsp_root(bufnr or vim.api.nvim_get_current_buf())
  if root then
    if vim.g.project_switch_root ~= root then
      vim.g.project_switch_root = root
    end
    if not vim.list_contains({ (uv.cwd() or vim.fn.getcwd()), vim.g.project_switch_root }, root) then
      Log.debug(('(SWITCH.lsp): found `%s` root at `%s`.'):format(lsp_name, root))
    end
    return true, root, ('"%s" lsp'):format(lsp_name)
  end
  return false
end

---@param bufnr? integer
---@return boolean success
---@return string|nil root
---@return string|nil method
---@nodiscard
function SWITCH.pattern(bufnr)
  Util.validate({ bufnr = { bufnr, { 'number', 'nil' }, true } })
  bufnr = (bufnr and Util.is_int(bufnr, bufnr >= 0)) and bufnr or vim.api.nvim_get_current_buf()

  local root, method = M.find_pattern_root(bufnr or vim.api.nvim_get_current_buf())
  if root then
    if vim.g.project_switch_root ~= root then
      vim.g.project_switch_root = root
    end
    if not vim.list_contains({ (uv.cwd() or vim.fn.getcwd()), vim.g.project_switch_root }, root) then
      Log.debug(('(SWITCH.lsp): found `%s` root at `%s`.'):format(method, root))
    end
    return true, root, method
  end
  return false
end

---@param bufnr? integer
---@return string|nil dir
---@nodiscard
function M.check_oil(bufnr)
  Util.validate({ bufnr = { bufnr, { 'number', 'nil' }, true } })
  bufnr = (bufnr and Util.is_int(bufnr, bufnr >= 0)) and bufnr or vim.api.nvim_get_current_buf()

  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local ok, oil = pcall(require, 'oil')
  local dir ---@type string|nil

  ---SOURCE: https://github.com/cosmicbuffalo/root_swapper.nvim/blob/main/lua/root_swapper.lua
  dir = (ok and oil and oil.get_current_dir) and oil.get_current_dir(bufnr) or bufname:gsub('^oil://', '')

  if dir then
    dir = Util.strip_slash(dir)
  end
  return dir
end

---@overload fun(): last: string|nil
---@overload fun(full_entry: false): last: string|nil
---@overload fun(full_entry: true): last: ProjectHistoryEntry|nil
---@nodiscard
function M.get_last_project(full_entry)
  Util.validate({ full_entry = { full_entry, { 'boolean', 'nil' }, true } })
  if full_entry == nil then
    full_entry = false
  end

  local recent = Util.reverse(History.get_recent_projects())
  if vim.tbl_isempty(recent) or #recent == 1 then
    return
  end

  local res = #History.session_projects <= 1 and recent[2] or recent[1]
  if History.legacy then
    ---@cast res string
    return res
  end

  ---@cast res ProjectHistoryEntry
  return full_entry and res or res.path
end

---@overload fun(): history_paths: HistoryPath
---@overload fun(path: ProjectPaths): history_paths: string
---@nodiscard
function M.get_history_paths(path)
  Util.validate({ path = { path, { 'string', 'nil' }, true } })

  local res = { ---@type HistoryPath
    datapath = Path.datapath,
    projectpath = Path.projectpath,
    historyfile = Path.historyfile,
  }
  if path and in_list(vim.tbl_keys(res), path) then
    return Path[path] --[[@as string]]
  end
  return res
end

---Get the LSP client for current buffer.
---
---If successful, returns a tuple of two `string` results.
---Otherwise, nothing is returned.
--- ---
---@param bufnr? integer
---@return string|nil dir
---@return string|nil name
---@nodiscard
function M.find_lsp_root(bufnr)
  Util.validate({ bufnr = { bufnr, { 'number', 'nil' }, true } })
  bufnr = (bufnr and Util.is_int(bufnr, bufnr >= 0)) and bufnr or vim.api.nvim_get_current_buf()

  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if vim.tbl_isempty(clients) then
    return
  end

  local ignore_lsp = Config.options.lsp.ignore
  local ft = Util.optget('filetype', 'buf', bufnr)
  for _, client in ipairs(clients) do
    local filetypes = client.config.filetypes --[[@as string[]\]]
    local valid = (
      Util.is_type('table', filetypes)
      and in_list(filetypes, ft)
      and not in_list(ignore_lsp, client.name)
      and client.config.root_dir
    )
    if valid then
      if Config.options.lsp.use_pattern_matching and Path.root_included(client.config.root_dir) == nil then
        return
      end
      return client.config.root_dir, client.name
    end
  end
end

---@param bufnr? integer
---@return string|nil dir_res
---@return string|nil method
---@nodiscard
function M.find_pattern_root(bufnr)
  Util.validate({ bufnr = { bufnr, { 'number', 'nil' }, true } })
  bufnr = (bufnr and Util.is_int(bufnr, bufnr >= 0)) and bufnr or vim.api.nvim_get_current_buf()

  local dir = M.check_oil(bufnr) or vim.api.nvim_buf_get_name(bufnr)
  dir = vim.fn.isdirectory(dir) == 1 and dir or Util.strip_slash(dir, ':p:h') ---@type string
  return Path.root_included(Util.is_windows() and dir:gsub('\\', '/') or dir)
end

---@param bufnr? integer
---@return boolean valid
---@nodiscard
function M.valid_bt(bufnr)
  Util.validate({ bufnr = { bufnr, { 'number', 'nil' }, true } })
  bufnr = (bufnr and Util.is_int(bufnr, bufnr >= 0)) and bufnr or vim.api.nvim_get_current_buf()

  return Util.buffer_valid(bufnr) and not in_list(Config.options.disable_on.bt, Util.optget('buftype', 'buf', bufnr))
end

---@param dir string
---@param method string
---@return boolean success
function M.set_pwd(dir, method)
  Util.validate({
    dir = { dir, { 'string' } },
    method = { method, { 'string' } },
  })
  dir = Util.strip_slash(dir)
  if not Path.exists(dir) then
    return false
  end

  if not Path.verify_owner(dir) then
    Log.warn(('(%s.set_pwd): Project is owned by a different user'):format(MODSTR))
    if Config.options.different_owners.notify then
      vim.notify(('(%s.set_pwd): Project is owned by a different user'):format(MODSTR), ERROR)
    end
    if not Config.options.different_owners.allow then
      return false
    end
  end

  History.session_projects = History.session_projects or {}

  local unexpand_dir, modified = Util.strip_slash(dir, ':p:~'), false
  if
    not vim.tbl_contains(History.session_projects, function(val)
      return (History.legacy and val or val.path) == dir
    end, { predicate = true })
  then
    table.insert(History.session_projects, History.legacy and dir or {
      path = dir,
      name = History.find_entry('recent', dir, 'name')
        or Util.strip_slash(dir, ':p:h:h:t') .. '/' .. Util.strip_slash(dir, ':p:h:t'),
    })
    modified = true
    Log.info(
      ('(%s.set_pwd): Added project `%s` to the top of session list'):format(
        MODSTR,
        Util.strip_slash(unexpand_dir, ':p:~')
      )
    )
  end
  if not modified and #History.session_projects > 1 then
    local old_pos, name = nil, '' ---@type integer|nil, string
    for k, v in ipairs(History.session_projects) do
      if (History.legacy and v or v.path) == dir then
        old_pos = k
        if not History.legacy then
          name = v.name
        end
        break
      end
    end
    if old_pos and old_pos ~= 1 then
      table.remove(History.session_projects, old_pos)
      table.insert(History.session_projects, 1, History.legacy and dir or { path = dir, name = name })
      Log.debug(
        ('(%s.set_pwd): Moved project `%s` from `%d` to the top of session list'):format(
          MODSTR,
          Util.strip_slash(unexpand_dir, ':p:~'),
          old_pos
        )
      )
    end
  end

  local before_attach = Config.options.before_attach
  if before_attach and vim.is_callable(before_attach) then
    local ok = pcall(before_attach, dir, method)
    if ok then
      Log.debug(('(%s.set_pwd): Ran `before_attach` hook successfully.'):format(MODSTR))
    end
  end

  if dir == Util.strip_slash(uv.cwd() or vim.fn.getcwd()) then
    M.current_project = dir
    M.current_method = method
    if vim.g.project_cwd_log ~= 1 then
      Log.info(('(%s.set_pwd): Current directory is selected project.'):format(MODSTR))
    end
    vim.g.project_cwd_log = 1
    return true
  end

  local scope_chdir = Config.options.scope_chdir
  local msg = ('(%s.set_pwd):'):format(MODSTR)
  if not in_list({ 'global', 'tab', 'win' }, scope_chdir) then
    Log.error(('%s INVALID value for `scope_chdir`: `%s`'):format(msg, vim.inspect(scope_chdir)))
    vim.notify(('%s INVALID value for `scope_chdir`: `%s`'):format(msg, vim.inspect(scope_chdir)), ERROR)
  end

  vim.g.project_cwd_log = 0
  local ok = pcall(
    scope_chdir == 'global' and vim.api.nvim_set_current_dir
      or (scope_chdir == 'tab' and vim.cmd.tchdir or (scope_chdir == 'win' and vim.cmd.lchdir)),
    dir
  )

  msg = ('%s chdir: `%s`, method: `%s`, status: `%s`'):format(msg, dir, method, (ok and 'SUCCESS' or 'FAILED'))

  if ok then
    M.current_project = dir
    M.current_method = method

    Log.info(msg)
    local on_attach = Config.options.on_attach
    if on_attach and vim.is_callable(on_attach) then
      on_attach(dir, method)
      Log.debug(('(%s.set_pwd): Ran `on_attach` hook successfully.'):format(MODSTR))
    end

    Log.debug(
      ('(%s.set_pwd): Changed directory to `%s` using method `%s`'):format(
        MODSTR,
        Util.strip_slash(dir, ':p:~'),
        method
      )
    )
    History.write_history()
  else
    Log.error(msg)
  end

  if not Config.options.silent_chdir then
    vim.notify(msg, (ok and INFO or ERROR))
  end
  return ok
end

---Returns the project root, as well as the method used.
---
---If no project root is found, nothing will be returned.
--- ---
---@param bufnr? integer
---@return string|nil root
---@return string|nil method
---@nodiscard
function M.get_project_root(bufnr)
  Util.validate({ bufnr = { bufnr, { 'number', 'nil' }, true } })
  bufnr = (bufnr and Util.is_int(bufnr, bufnr >= 0)) and bufnr or vim.api.nvim_get_current_buf()
  if not Util.buffer_valid(bufnr) or vim.tbl_isempty(Config.detection_methods) then
    return
  end

  local roots = {} ---@type { root: string, method_msg: string, method: 'lsp'|'pattern' }[]
  local root, method = nil, nil ---@type string|nil, string|nil
  local ops = vim.tbl_keys(SWITCH) ---@type ('lsp'|'pattern')[]
  local success = false
  for _, m in ipairs(Config.detection_methods) do
    if in_list(ops, m) then
      ---@type boolean, string|nil, string|nil
      success, root, method = SWITCH[m](bufnr)
      if success then
        table.insert(roots, { root = root, method_msg = method, method = m })
      end
    end
  end

  if vim.tbl_isempty(roots) then
    return
  end

  if #roots == 1 or Config.options.lsp.no_fallback then
    return roots[1].root, roots[1].method_msg
  end
  if roots[1].root == roots[2].root then
    return roots[1].root, roots[1].method_msg
  end

  for _, tbl in ipairs(roots) do
    if tbl.method == 'pattern' then
      return tbl.root, tbl.method_msg
    end
  end
end

---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/149
--- ---
---@param bufnr? integer
---@return string|nil curr
---@return string|nil method
---@return string|nil last
---@nodiscard
function M.get_current_project(bufnr)
  Util.validate({ bufnr = { bufnr, { 'number', 'nil' }, true } })
  bufnr = (bufnr and Util.is_int(bufnr, bufnr >= 0)) and bufnr or vim.api.nvim_get_current_buf()

  if not Util.buffer_valid(bufnr) then
    return
  end

  local curr, method = M.get_project_root(bufnr)
  local last = M.get_last_project()
  return curr, method, last
end

---@param bufnr? integer
---@return string|nil name
---@nodiscard
function M.get_current_project_name(bufnr)
  Util.validate({ bufnr = { bufnr, { 'number', 'nil' }, true } })
  bufnr = (bufnr and Util.is_int(bufnr, bufnr >= 0)) and bufnr or vim.api.nvim_get_current_buf()

  if not Util.buffer_valid(bufnr) then
    return
  end

  local curr = M.get_project_root(bufnr)
  return History.find_entry('recent', curr, 'name')
end

---@param bufnr? integer
function M.on_buf_enter(bufnr)
  Util.validate({ bufnr = { bufnr, { 'number', 'nil' }, true } })
  bufnr = (bufnr and Util.is_int(bufnr, bufnr >= 0)) and bufnr or vim.api.nvim_get_current_buf()
  if not (Util.buffer_valid(bufnr) and M.valid_bt(bufnr)) then
    return
  end

  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local dir = M.check_oil(bufnr) or ''

  dir = dir == '' and Util.strip_slash(bufname, ':p:h') or Util.strip_slash(dir)
  dir = Util.is_windows() and dir:gsub('\\', '/') or dir
  if not (Path.exists(dir) and Path.root_included(dir)) or Path.is_excluded(dir) then
    return
  end

  local ft = Util.optget('filetype', 'buf', bufnr)
  if in_list(Config.options.disable_on.ft, ft) then
    return
  end

  M.current_project, M.current_method = M.get_current_project(bufnr)
  local change = M.current_project ~= (uv.cwd() or vim.fn.getcwd())
  M.set_pwd(M.current_project, M.current_method)

  if change then
    M.last_project = M.get_last_project()
  end
  History.write_history()
end

---@param scan_what? 'visible_files'|'visible_directories'|'all_visible'|'all_files'|'all_directories'|'all'|'hidden_files'|'hidden_directories'|'all_hidden'
---@param path? string
---@param prefix? string
---@return string[]|nil files_list
function M.root_files(scan_what, path, prefix)
  if vim.g.project_setup ~= 1 then
    return
  end
  Util.validate({
    scan_what = { scan_what, { 'string', 'nil' }, true },
    path = { path, { 'string', 'nil' }, true },
    prefix = { prefix, { 'string', 'nil' }, true },
  })
  if not scan_what then
    scan_what = Config.options.show_hidden and 'all' or 'all_visible'
  end
  if not path or path == '' then
    path = M.get_current_project() or M.get_project_root()
    if not path then
      return
    end
  end

  if
    not vim.list_contains({
      'all',
      'all_directories',
      'all_files',
      'all_hidden',
      'all_visible',
      'hidden_directories',
      'hidden_files',
      'visible_directories',
      'visible_files',
    }, scan_what)
  then
    error(('(%s.root_files): Invalid parameter `%s`!'):format(MODSTR, scan_what), ERROR)
  end
  if not Path.exists(path) or vim.fn.isdirectory(path) ~= 1 then
    error(('(%s.root_files): Invalid path `%s`!'):format(MODSTR, path), ERROR)
  end

  local dir = uv.fs_scandir(path)
  if not dir then
    return
  end

  local files = {} ---@type string[]
  local next, ftype = uv.fs_scandir_next(dir)
  while next ~= nil do
    local is_hidden = Path.is_hidden(next)
    local is_type ---@type boolean
    if scan_what == 'all_files' then
      is_type = ftype == 'file'
    elseif scan_what == 'visible_files' then
      is_type = ftype == 'file' and not is_hidden
    elseif scan_what == 'hidden_files' then
      is_type = ftype == 'file' and is_hidden
    elseif scan_what == 'all_directories' then
      is_type = ftype == 'directory'
    elseif scan_what == 'visible_directories' then
      is_type = ftype == 'directory' and not is_hidden
    elseif scan_what == 'hidden_directories' then
      is_type = ftype == 'directory' and is_hidden
    elseif scan_what == 'all_visible' then
      is_type = vim.list_contains({ 'file', 'directory' }, ftype) and not is_hidden
    elseif scan_what == 'all_hidden' then
      is_type = vim.list_contains({ 'file', 'directory' }, ftype) and is_hidden
    elseif scan_what == 'all' then
      is_type = vim.list_contains({ 'file', 'directory' }, ftype)
    end
    if is_type then
      table.insert(files, prefix and vim.fs.joinpath(prefix, next) or next)
    end
    next, ftype = uv.fs_scandir_next(dir)
  end

  return vim.tbl_isempty(files) and nil or files
end

function M.setup()
  local group = vim.api.nvim_create_augroup('project.nvim', { clear = true })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      History.write_history()
    end,
  })

  if not Config.options.manual_mode then
    if in_list(Config.detection_methods, 'pattern') then
      vim.api.nvim_create_autocmd('BufEnter', {
        group = group,
        nested = true,
        callback = function(ev)
          M.on_buf_enter(ev.buf)
        end,
      })
      vim.g.project_pattern_attach = 1
    end
    if in_list(Config.detection_methods, 'lsp') then
      vim.api.nvim_create_autocmd('LspAttach', {
        group = group,
        nested = true,
        callback = function(ev)
          M.on_buf_enter(ev.buf)
        end,
      })
      vim.g.project_lsp_attach = 1
    end
  end
  History.read_history()
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
