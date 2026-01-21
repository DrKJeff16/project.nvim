---@class Project.HistoryPath
---@field name string
---@field type string
---@field path string

local MODSTR = 'project.health'

local Util = require('project.util')
local Config = require('project.config')
local Path = require('project.util.path')
local History = require('project.util.history')
local Log = require('project.util.log')
local Api = require('project.api')

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
    vim.health.ok(('nvim version is at least `v0.11` (`%s`)'):format(version))
  else
    vim.health.warn(('nvim version is lower than `v0.11`! (`%s`)'):format(version))
  end

  if not (Util.executable('fd') or Util.executable('fdfind')) then
    vim.health.warn('`fd` nor `fdfind` were found! Some utilities from this plugin may not work.')
  else
    vim.health.ok(('`%s` executable in `PATH`'):format(Util.executable('fd') and 'fd' or 'fdfind'))
  end

  if Util.is_windows() and vim.g.project_disable_win32_warning ~= 1 then
    vim.health.warn([[
`DISCLAIMER`

You're running on Windows. Issues are more likely to occur,
bear that in mind.

Please report any issues to the maintainers.

If you wish to disable this warning, set `g:project_disable_win32_warning` to `1`.
            ]])
  end
  return true
end

function M.options_check()
  vim.health.start('Config')
  local Options = vim.deepcopy(Config.options)
  if not Util.is_type('table', Options) then
    vim.health.error('The config table is missing!')
    return
  end
  table.sort(Options)
  local exceptions = {
    'expand_excluded',
    'fzf_lua',
    'gen_methods',
    'new',
    'telescope',
    'verify',
    'verify_datapath',
    'verify_histsize',
    'verify_logging',
    'verify_lsp',
    'verify_scope_chdir',
  }
  for k, v in pairs(Options) do
    if not vim.list_contains(exceptions, k) then
      local constraints = nil ---@type string[]|nil
      if k == 'scope_chdir' then
        constraints = { 'global', 'tab', 'win' }
      end

      local str, warning = Util.format_per_type(type(v), v, nil, constraints)
      str = (' - %s: %s'):format(k, str)
      if Util.is_type('boolean', warning) and warning then
        vim.health.warn(str)
      else
        vim.health.ok(str)
      end
    end
  end
end

function M.history_check()
  vim.health.start('History')
  local P = { ---@type Project.HistoryPath[]
    { name = 'datapath', type = 'directory', path = Path.datapath },
    { name = 'projectpath', type = 'directory', path = Path.projectpath },
    { name = 'historyfile', type = 'file', path = Path.historyfile },
  }
  for _, v in ipairs(P) do
    local name, ptype, path = v.name, v.type, v.path
    local stat = (vim.uv or vim.loop).fs_stat(path)
    if not stat then
      vim.health.error(('%s: `%s` is missing or not readable!'):format(name, path))
      return
    end
    if stat.type ~= ptype then
      vim.health.error(('%s: `%s` is not of type `%s`!'):format(name, path, ptype))
      return
    end
    vim.health.ok(('%s: `%s`'):format(name, path))
  end
end

function M.project_check()
  vim.health.start('Current Project')
  local curr, method, last = Api.current_project, Api.current_method, Api.last_project
  local msg = ('Current project: `%s`\n'):format(curr ~= nil and curr or 'No Current Project')
  msg = ('%sMethod used: `%s`\n'):format(msg, (method ~= nil and method or 'No method available'))
  msg = ('%sLast project: `%s`'):format(msg, (last ~= nil and last or 'No Last Project In History'))
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
  local active = History.has_watch_setup
  local projects = vim.deepcopy(History.session_projects)
  if not active or vim.tbl_isempty(projects) then
    vim.health.warn('No active session projects!')
    return
  end
  for k, v in ipairs(Util.dedup(projects)) do
    vim.health.info(('%s. `%s`'):format(k, v))
  end
end

function M.fzf_lua_check()
  vim.health.start('Fzf-Lua')
  if not Config.options.fzf_lua.enabled then
    vim.health.warn([[
`fzf-lua` integration is disabled.

This doesn't represent an issue necessarily!
            ]])
    return
  end

  vim.health.ok('`fzf-lua` integration enabled!')
  if not (vim.cmd.ProjectFzf and vim.is_callable(vim.cmd.ProjectFzf)) then
    vim.health.warn('`:ProjectFzf` user command is not loaded!')
  else
    vim.health.ok('`:ProjectFzf` user command loaded!')
  end
end

function M.recent_proj_check()
  vim.health.start('Recent Projects')
  local recents = History.get_recent_projects()
  if vim.tbl_isempty(recents) then
    vim.health.warn([[
`No projects found in history!`

If this is your first time using this plugin,
or you just set a different `historypath` for your plugin,
then you can ignore this.

If this keeps appearing, though, check your config
and submit an issue if pertinent.
            ]])
    return
  end
  recents = Util.reverse(recents) ---@type string[]
  for i, project in ipairs(recents) do
    vim.health.info(('`%s`. `%s`'):format(i, project))
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
  M.fzf_lua_check()
  M.options_check()
  M.recent_proj_check()

  Log.debug(('(%s): `checkhealth` successfully called.'):format(MODSTR))
end

local Health = setmetatable(M, { ---@type Project.Health
  __index = M,
  __newindex = function()
    vim.notify('Project.Health is Read-Only!', vim.log.levels.ERROR)
  end,
})

return Health
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
