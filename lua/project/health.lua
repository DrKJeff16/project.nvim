---@module 'project._meta'

local Util = require('project.util')

---@class Project.Health
local M = {}

---@return boolean setup_called
---@nodiscard
local function setup_check()
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

local function options_check()
  vim.health.start('Configuration')
  local Options = require('project.config').get()
  if Util.is_type('table', Options) then
    table.sort(Options)
    for k, v in pairs(Options) do
      local constraints = nil ---@type string[]|nil|?
      if k == 'scope_chdir' then
        constraints = { 'global', 'tab', 'win' }
      end

      local str, warning = Util.format_per_type(type(v), v, nil, constraints)
      local func = warning and vim.health.warn or vim.health.ok
      func((' - `%s`: %s'):format(k, str))
    end
  else
    vim.health.error('The config table is missing!')
  end
end

local function history_check()
  vim.health.start('History')
  local P = { ---@type Project.HistoryPath[]
    { name = 'datapath', type = 'directory', path = Util.path.datapath },
    { name = 'projectpath', type = 'directory', path = Util.path.projectpath },
    { name = 'historyfile', type = 'file', path = Util.path.historyfile },
  }
  for _, v in ipairs(P) do
    local stat = vim.uv.fs_stat(v.path)
    if stat then
      if stat.type ~= v.type then
        vim.health.error(('%s: `%s` is not of type `%s`!'):format(v.name, v.path, v.type))
      else
        vim.health.info(('%s: `%s`'):format(v.name, v.path))
      end
    else
      vim.health.error(('%s: `%s` is missing or not readable!'):format(v.name, v.path))
    end
  end
end

local function project_check()
  local Core = require('project.core')

  vim.health.start('Current Project')
  local curr, method, last = Core.get_current_project(), Core.get_current_method(), Core.get_last_project()
  local msg = ('Current project: `%s`\n'):format(curr and curr or 'No Current Project')
  msg = ('%sMethod used: `%s`\n'):format(msg, (method and method or 'No method available'))
  msg = ('%sLast project: `%s`'):format(msg, (last and last or 'No Last Project In History'))
  vim.health.info(msg)

  vim.health.start('Detection Methods')
  local methods = require('project.config').get_detection_methods()
  msg = ''
  for k, m in ipairs(methods) do
    local str = Util.format_per_type(type(m), m)
    msg = ('%s\n[`%d`]: %s'):format(msg, k, str)
  end
  vim.health.info(msg)

  vim.health.start('Active Sessions')
  local projects = Util.history.get_session_projects()
  if vim.g.project_history_has_watch_setup == 1 and not vim.tbl_isempty(projects) then
    for k, v in ipairs(Util.dedup(projects, 'name')) do
      local index = tostring(k)
      vim.health.info(('%d. `%s`\n   %spath: `%s`'):format(index, v.name, (' '):rep(index:len() - 1), v.path))
    end
  else
    vim.health.warn('No active session projects!')
  end
end

local function logging_check()
  vim.health.start('Log')
  if require('project.config').get().log.enabled and vim.g.project_log_loaded == 1 then
    vim.health.ok('Logging enabled!')
    vim.health.ok('`:Project log` user command available!')
  else
    vim.health.ok('Logging disabled. This does not represent an issue necessarily!')
  end
end

local function fzf_lua_check()
  vim.health.start('`fzf-lua` Integration')
  if require('project.config').get().fzf_lua.enabled and vim.g.project_fzf_lua_loaded == 1 then
    vim.health.ok('`fzf-lua` integration enabled!')
    vim.health.ok('`:Project fzf-lua` user command available!')
  else
    vim.health.warn('`fzf-lua` integration is disabled. This does not represent an issue necessarily!')
  end
end

local function recent_proj_check()
  vim.health.start('Recent Projects')
  local recents = Util.reverse(Util.history.get_recent_projects())
  if not vim.tbl_isempty(recents) then
    for i, project in ipairs(recents) do
      local index = tostring(i)
      vim.health.info(
        ('%d. `%s`\n   %spath: `%s`'):format(index, project.name, (' '):rep(index:len() - 1), project.path)
      )
    end
  else
    vim.health.warn([[No projects found in history!

If this is your first time using this plugin,
or you just set a different `historypath` for your plugin,
then you can ignore this.

If this keeps appearing, though, check your config
and submit an issue if pertinent.]])
  end
end

---This is called when running `:checkhealth project`.
--- ---
function M.check()
  if setup_check() then
    project_check()
    history_check()
    options_check()
    logging_check()
    fzf_lua_check()
    recent_proj_check()

    Util.log.debug('(project.health): `checkhealth` successfully called.')
  end
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
