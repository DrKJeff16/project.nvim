local MODSTR = 'project.health'
local Util = require('project.util')

local function setup_check()
  local setup_called = vim.g.project_setup == 1
  if not setup_called then
    vim.health.error('`setup()` has not been called!')
    return setup_called
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
  return true
end

local function telescope_check()
  if not Util.mod_exists('telescope') then
    vim.health.error('`telescope.nvim` is not installed!')
    return
  end
  if not require('telescope').extensions.projects then
    vim.health.error('`projects` Telescope picker is missing!\nHave you loaded it?')
    return
  end
  vim.health.ok('`projects` picker extension loaded')

  local opts_telescope = require('project.config').options.telescope
  if not Util.is_type('table', opts_telescope) then
    vim.health.warn('`projects` does not have telescope options set up')
    return
  end

  for k, v in pairs(opts_telescope) do
    local str, warning = Util.format_per_type(type(v), v)
    str = ('`%s`: %s'):format(k, str)
    if Util.is_type('boolean', warning) and warning then
      vim.health.warn(str)
    else
      vim.health.ok(str)
    end
  end
end

---This is called when running `:checkhealth telescope`.
--- ---
local function health_check()
  if not setup_check() then
    return
  end

  telescope_check()
  require('project.util.log').debug(('(%s): `checkhealth` successfully called.'):format(MODSTR))
end

return health_check
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
