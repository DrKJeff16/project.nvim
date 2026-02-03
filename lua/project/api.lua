---For newcommers, in the original `project.nvim` this file was
---`project.lua`. I decided to make this an API file instead
---to avoid any confusions with naming,
---e.g. `require('project_nvim.project')`.

---@alias HistoryPath table<'datapath'|'projectpath'|'historyfile', string>

local MODSTR = 'project.api'
local ERROR = vim.log.levels.ERROR
local INFO = vim.log.levels.INFO
local uv = vim.uv or vim.loop
local Config = require('project.config')
local Path = require('project.util.path')
local Util = require('project.util')
local History = require('project.util.history')
local Log = require('project.util.log')

---The `project.nvim` API module.
--- ---
---@class Project.API
---@field last_project? string
---@field current_project? string
---@field current_method? string
local Api = {}

---@class ProjectRootSwitch
local SWITCH = {}

---@param bufnr? integer
---@return boolean success
---@return string|nil root
---@return string|nil method
---@nodiscard
function SWITCH.lsp(bufnr)
  Util.validate({ bufnr = { bufnr, { 'number', 'nil' }, true } })
  bufnr = (bufnr and bufnr > 0 and Util.is_int(bufnr)) and bufnr or vim.api.nvim_get_current_buf()

  local root, lsp_name = Api.find_lsp_root(bufnr or vim.api.nvim_get_current_buf())
  if root then
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
  bufnr = (bufnr and bufnr > 0 and Util.is_int(bufnr)) and bufnr or vim.api.nvim_get_current_buf()

  local root, method = Api.find_pattern_root(bufnr or vim.api.nvim_get_current_buf())
  if root then
    return true, root, method
  end
  return false
end

---@param bufnr integer
---@return boolean valid
function Api.buffer_valid(bufnr)
  Util.validate({ bufnr = { bufnr, { 'number' } } })

  return vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr)
end

---@return string|nil last
---@nodiscard
function Api.get_last_project()
  local recent = History.get_recent_projects()
  if vim.tbl_isempty(recent) or #recent == 1 then
    return
  end

  recent = Util.reverse(recent) ---@type string[]
  return #History.session_projects <= 1 and recent[2] or recent[1]
end

---@param path? 'datapath'|'projectpath'|'historyfile'
---@return string|HistoryPath history_paths
---@nodiscard
function Api.get_history_paths(path)
  Util.validate({ path = { path, { 'string', 'nil' }, true } })

  local res = { ---@type HistoryPath
    datapath = Path.datapath,
    projectpath = Path.projectpath,
    historyfile = Path.historyfile,
  }
  if path and vim.list_contains(vim.tbl_keys(res), path) then
    return Path[path]
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
function Api.find_lsp_root(bufnr)
  Util.validate({ bufnr = { bufnr, { 'number', 'nil' }, true } })
  bufnr = (bufnr and Util.is_int(bufnr)) and bufnr or vim.api.nvim_get_current_buf()

  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if vim.tbl_isempty(clients) then
    return
  end

  local ignore_lsp = Config.options.lsp.ignore
  local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
  for _, client in ipairs(clients) do
    ---@type string[]
    local filetypes = client.config.filetypes ---@diagnostic disable-line:undefined-field
    local valid = (
      Util.is_type('table', filetypes)
      and vim.list_contains(filetypes, ft)
      and not vim.tbl_isempty(filetypes)
      and not vim.list_contains(ignore_lsp, client.name)
      and client.config.root_dir
    )
    if valid then
      local dir, name = client.config.root_dir, client.name
      if Config.options.lsp.use_pattern_matching then
        if Path.root_included(dir) == nil then
          return
        end
      end
      return dir, name
    end
  end
end

---@param bufnr? integer
---@return string|nil dir_res
---@return string|nil method
---@nodiscard
function Api.find_pattern_root(bufnr)
  Util.validate({ bufnr = { bufnr, { 'number', 'nil' }, true } })
  bufnr = (bufnr and Util.is_int(bufnr)) and bufnr or vim.api.nvim_get_current_buf()

  local dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':p:h')
  dir = Util.is_windows() and dir:gsub('\\', '/') or dir
  return Path.root_included(dir)
end

---@param bufnr? integer
---@return boolean valid
---@nodiscard
function Api.valid_bt(bufnr)
  Util.validate({ bufnr = { bufnr, { 'number', 'nil' }, true } })
  bufnr = (bufnr and bufnr > 0 and Util.is_int(bufnr)) and bufnr or vim.api.nvim_get_current_buf()

  if not Api.buffer_valid(bufnr) then
    return false
  end

  local bt = vim.api.nvim_get_option_value('buftype', { buf = bufnr })
  return not vim.list_contains(Config.options.disable_on.bt, bt)
end

---Generates the autocommand for the `LspAttach` event.
---
---**_An `augroup` ID is mandatory!_**
--- ---
---@param group integer
function Api.gen_lsp_autocmd(group)
  Util.validate({ group = { group, { 'number' } } })
  if not Util.is_int(group) then
    error(('Parameter group is not an integer `%s`'):format(group))
  end

  if vim.g.project_lspattach == 1 then
    return
  end

  vim.api.nvim_create_autocmd('LspAttach', {
    group = group,
    nested = true,
    callback = function(ev)
      Api.on_buf_enter(ev.buf)
    end,
  })
  vim.g.project_lspattach = 1
end

---@param dir string
---@param method string
---@return boolean success
function Api.set_pwd(dir, method)
  Util.validate({
    dir = { dir, { 'string' } },
    method = { method, { 'string' } },
  })
  dir = vim.fn.expand(dir)

  if not Path.verify_owner(dir) then
    Log.warn(('(%s.set_pwd): Project is owned by a different user'):format(MODSTR))
    if Config.options.different_owners.notify then
      vim.notify(('(%s.set_pwd): Project is owned by a different user'):format(MODSTR), ERROR)
    end
    if not Config.options.different_owners.allow then
      return false
    end
  end

  local modified = false
  if vim.tbl_isempty(History.session_projects) then
    History.session_projects = { dir }
    modified = true
  elseif not vim.list_contains(History.session_projects, dir) then
    table.insert(History.session_projects, dir)
    modified = true
  end
  if not modified and #History.session_projects > 1 then
    local old_pos ---@type integer
    for k, v in ipairs(History.session_projects) do
      if v == dir then
        old_pos = k
        break
      end
    end
    table.remove(History.session_projects, old_pos)
    table.insert(History.session_projects, 1, dir) -- HACK: Move project to start of table
  end

  local cwd = uv.cwd() or vim.fn.getcwd()
  if dir == cwd then
    Api.current_project = dir
    Api.current_method = method
    if vim.g.project_cwd_log ~= 1 then
      Log.info(('(%s.set_pwd): Current directory is selected project.'):format(MODSTR))
    end
    vim.g.project_cwd_log = 1
    return true
  end
  if Config.options.before_attach and vim.is_callable(Config.options.before_attach) then
    Config.options.before_attach(dir, method)
    Log.debug(('(%s.set_pwd): Ran `before_attach` hook successfully.'):format(MODSTR))
  end

  local scope_chdir = Config.options.scope_chdir
  local msg = ('(%s.set_pwd):'):format(MODSTR)
  if not vim.list_contains({ 'global', 'tab', 'win' }, scope_chdir) then
    Log.error(('%s INVALID value for `scope_chdir`: `%s`'):format(msg, vim.inspect(scope_chdir)))
    vim.notify(
      ('%s INVALID value for `scope_chdir`: `%s`'):format(msg, vim.inspect(scope_chdir)),
      ERROR
    )
  end

  vim.g.project_cwd_log = 0
  local ok = false
  if scope_chdir == 'global' then
    ok = pcall(vim.api.nvim_set_current_dir, dir)
    msg = ('%s\nchdir: `%s`:'):format(msg, dir)
  elseif scope_chdir == 'tab' then
    ok = pcall(vim.cmd.tchdir, dir)
    msg = ('%s\ntchdir: `%s`:'):format(msg, dir)
  elseif scope_chdir == 'win' then
    ok = pcall(vim.cmd.lchdir, dir)
    msg = ('%s\nlchdir: `%s`:'):format(msg, dir)
  end
  msg = ('%s\nMethod: %s\nStatus: %s'):format(msg, method, (ok and 'SUCCESS' or 'FAILED'))
  if ok then
    Api.current_project = dir
    Api.current_method = method

    Log.info(msg)
    if Config.options.on_attach and vim.is_callable(Config.options.on_attach) then
      Config.options.on_attach(dir, method)
      Log.debug(('(%s.set_pwd): Ran `on_attach` hook successfully.'):format(MODSTR))
    end
  else
    Log.error(msg)
  end

  if not Config.options.silent_chdir then
    vim.schedule(function()
      vim.notify(msg, (ok and INFO or ERROR))
    end)
  end

  if ok then
    Log.debug(('Changed directory to `%s` using method `%s`'):format(dir, method))
    History.write_history()
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
function Api.get_project_root(bufnr)
  Util.validate({ bufnr = { bufnr, { 'number', 'nil' }, true } })
  bufnr = (bufnr and bufnr > 0 and Util.is_int(bufnr)) and bufnr or vim.api.nvim_get_current_buf()

  if not Api.buffer_valid(bufnr) then
    return
  end
  if vim.tbl_isempty(Config.detection_methods) then
    return
  end
  local roots = {} ---@type { root: string, method_msg: string, method: 'lsp'|'pattern' }[]
  local root, lsp_method = nil, nil
  local ops = vim.tbl_keys(SWITCH) ---@type ('lsp'|'pattern')[]
  local success = false
  for _, method in ipairs(Config.detection_methods) do
    if vim.list_contains(ops, method) then
      success, root, lsp_method = SWITCH[method](bufnr)
      if success then
        ---@cast root string
        ---@cast lsp_method string
        table.insert(roots, { root = root, method_msg = lsp_method, method = method })
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
function Api.get_current_project(bufnr)
  Util.validate({ bufnr = { bufnr, { 'number', 'nil' }, true } })
  bufnr = (bufnr and bufnr > 0 and Util.is_int(bufnr)) and bufnr or vim.api.nvim_get_current_buf()

  if not Api.buffer_valid(bufnr) then
    return
  end

  local curr, method = Api.get_project_root(bufnr)
  local last = Api.get_last_project()
  return curr, method, last
end

---@param bufnr? integer
function Api.on_buf_enter(bufnr)
  Util.validate({ bufnr = { bufnr, { 'number', 'nil' }, true } })
  bufnr = (bufnr and bufnr > 0 and Util.is_int(bufnr)) and bufnr or vim.api.nvim_get_current_buf()
  if not (Api.buffer_valid(bufnr) and Api.valid_bt(bufnr)) then
    return
  end

  local dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':p:h')
  dir = Util.is_windows() and dir:gsub('\\', '/') or dir
  if not (Path.exists(dir) and Path.root_included(dir)) or Path.is_excluded(dir) then
    return
  end

  local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
  if vim.list_contains(Config.options.disable_on.ft, ft) then
    return
  end

  Api.current_project, Api.current_method = Api.get_current_project(bufnr)
  local change = Api.current_project ~= vim.fn.getcwd(0, 0)
  Api.set_pwd(Api.current_project, Api.current_method)

  if change then
    Api.last_project = Api.get_last_project()
  end
  History.write_history()
end

function Api.init()
  local group = vim.api.nvim_create_augroup('project.nvim', { clear = true })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      History.write_history()
    end,
  })
  if not Config.options.manual_mode then
    if vim.list_contains(Config.detection_methods, 'pattern') then
      vim.api.nvim_create_autocmd('BufEnter', {
        group = group,
        nested = true,
        callback = function(ev)
          Api.on_buf_enter(ev.buf)
        end,
      })
    end
    if vim.list_contains(Config.detection_methods, 'lsp') then
      Api.gen_lsp_autocmd(group)
    end
  end
  History.read_history()
end

return Api
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
