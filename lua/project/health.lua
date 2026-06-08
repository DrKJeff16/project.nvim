---@module 'project._meta'

local MODSTR = 'project.health'
local uv = vim.uv or vim.loop
local Config = require('project.config')
local Core = require('project.core')
local Util = require('project.util')

---@class Project.Health
local M = {}

---@return boolean setup_called
---@nodiscard
function M.setup_check()
  vim.health.start('Setup')
  if not vim.g.project_setup == 1 then
    vim.health.error('`setup()` has not been called!')
    return false
  end

  vim.health.ok('`setup()` has been called!')

  local split_opts = { plain = true, trimempty = true } ---@type vim.gsplit.Opts
  local version = vim.split(
    vim.split(vim.api.nvim_exec2('version', { output = true }).output, '\n', split_opts)[1],
    ' ',
    split_opts
  )[2]
  if Util.vim_has('nvim-0.11') then
    vim.health.ok(('Neovim version is at least `v0.11` (`%s`)'):format(version))
  else
    vim.health.warn(('Neovim version is lower than `v0.11`! (`%s`)'):format(version))
  end

  if not (Util.executable('fd') or Util.executable('fdfind')) then
    vim.health.warn('`fd` nor `fdfind` were found! Some utilities from this plugin may not work.')
  else
    vim.health.ok(('`%s` executable in `PATH`'):format(Util.executable('fd') and 'fd' or 'fdfind'))
  end

  if Util.is_windows() and vim.g.project_disable_win32_warning ~= 1 then
    vim.health.warn([[DISCLAIMER

You're running on Windows. Issues are more likely to occur,
bear that in mind.

Please report any issues to the maintainers.

If you wish to disable this warning, set `g:project_disable_win32_warning` to `1`.]])
  end

  return true
end

function M.options_check()
  vim.health.start('Configuration')
  local Options = vim.deepcopy(Config.options)
  if not Util.is_type('table', Options) then
    vim.health.error('The config table is missing!')
    return
  end
  table.sort(Options)
  for k, v in pairs(Options) do
    local constraints = nil ---@type string[]|nil
    if k == 'scope_chdir' then
      constraints = { 'global', 'tab', 'win' }
    end

    local str, warning = Util.format_per_type(type(v), v, nil, constraints)
    local func = warning and vim.health.warn or vim.health.ok
    func((' - `%s`: %s'):format(k, str))
  end
end

function M.history_check()
  vim.health.start('History')
  local P = { ---@type Project.HistoryPath[]
    { name = 'datapath', type = 'directory', path = Util.path.datapath },
    { name = 'projectpath', type = 'directory', path = Util.path.projectpath },
    { name = 'historyfile', type = 'file', path = Util.path.historyfile },
  }
  for _, v in ipairs(P) do
    local name, ptype, path = v.name, v.type, v.path
    local stat = uv.fs_stat(path)
    if not stat then
      vim.health.error(('%s: `%s` is missing or not readable!'):format(name, path))
      return
    end
    if stat.type ~= ptype then
      vim.health.error(('%s: `%s` is not of type `%s`!'):format(name, path, ptype))
      return
    end
    vim.health.info(('%s: `%s`'):format(name, path))
  end
end

function M.project_check()
  vim.health.start('Current Project')
  local curr, method, last = Core.current_project, Core.current_method, Core.last_project
  local msg = ('Current project: `%s`\n'):format(curr and curr or 'No Current Project')
  msg = ('%sMethod used: `%s`\n'):format(msg, (method and method or 'No method available'))
  msg = ('%sLast project: `%s`'):format(msg, (last and last or 'No Last Project In History'))
  vim.health.info(msg)

  vim.health.start('Detection Methods')
  local methods = Config.detection_methods
  msg = ''
  for k, m in ipairs(methods) do
    local str = Util.format_per_type(type(m), m)
    msg = ('%s\n[`%d`]: %s'):format(msg, k, str)
  end
  vim.health.info(msg)

  vim.health.start('Active Sessions')
  local active = vim.g.project_history_has_watch_setup == 1
  local projects = vim.deepcopy(Util.history.session_projects)
  if not active or vim.tbl_isempty(projects) then
    vim.health.warn('No active session projects!')
    return
  end
  for k, v in ipairs(Util.dedup(projects, 'name')) do
    local index = tostring(k)
    vim.health.info(('%d. `%s`\n   %spath: `%s`'):format(index, v.name, (' '):rep(index:len() - 1), v.path))
  end
end

function M.logging_check()
  vim.health.start('Log')

  if not Config.options.log.enabled or vim.g.project_log_loaded ~= 1 then
    vim.health.ok('Logging disabled. This does not represent an issue necessarily!')
    return
  end

  vim.health.ok('Logging enabled!')
  vim.health.ok('`:Project log` user command available!')
end

function M.fzf_lua_check()
  vim.health.start('`fzf-lua` Integration')
  if not Config.options.fzf_lua.enabled or vim.g.project_fzf_lua_loaded ~= 1 then
    vim.health.warn('`fzf-lua` integration is disabled. This does not represent an issue necessarily!')
    return
  end

  vim.health.ok('`fzf-lua` integration enabled!')
  vim.health.ok('`:Project fzf-lua` user command available!')
end

function M.recent_proj_check()
  vim.health.start('Recent Projects')
  local recents = Util.reverse(Util.history.get_recent_projects(false))
  if vim.tbl_isempty(recents) then
    vim.health.warn([[No projects found in history!

If this is your first time using this plugin,
or you just set a different `historypath` for your plugin,
then you can ignore this.

If this keeps appearing, though, check your config
and submit an issue if pertinent.]])
    return
  end

  for i, project in ipairs(recents) do
    local index = tostring(i)
    vim.health.info(('%d. `%s`\n   %spath: `%s`'):format(index, project.name, (' '):rep(index:len() - 1), project.path))
  end
end

---This is called when running `:checkhealth project`.
--- ---
function M.check()
  if not M.setup_check() then
    return
  end
  M.project_check()
  M.history_check()
  M.options_check()
  M.logging_check()
  M.fzf_lua_check()
  M.recent_proj_check()

  Util.log.debug(('(%s): `checkhealth` successfully called.'):format(MODSTR))
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
