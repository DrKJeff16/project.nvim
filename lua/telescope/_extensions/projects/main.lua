local MODSTR = 'telescope._extensions.projects.main'
local ERROR = vim.log.levels.ERROR
if vim.g.project_setup ~= 1 then
  vim.notify(('(%s): `project.nvim` is not loaded!'):format(MODSTR), ERROR)
  return
end

local Log = require('project.util.log')
local Util = require('project.util')
local Config = require('project.config')
local Api = require('project.api')
if not Util.mod_exists('telescope') then
  Log.error(('(%s): Telescope is not installed!'):format(MODSTR))
  vim.notify(('(%s): Telescope is not installed!'):format(MODSTR), ERROR)
end

local Pickers = require('telescope.pickers')
local Actions = require('telescope.actions')
local State = require('telescope.actions.state')
local telescope_config = require('telescope.config').values
local _Actions = require('telescope._extensions.projects.actions')
local _Util = require('telescope._extensions.projects.util')

---@class Project.Telescope.Main
local M = {
  --- CREDITS: https://github.com/ldfwbebp/project.nvim/commit/954b8371aa1e517f0d47d48b49373d2365cc92d3
  default_opts = { prompt_prefix = '󱎸  ' },
}

local valid_acts = {
  'browse_project_files',
  'change_working_directory',
  'delete_project',
  'find_project_files',
  'help_mappings',
  'recent_project_files',
  'search_in_project_files',
}

---@param prompt_bufnr integer
---@param map fun(mode: string, lhs: string, rhs: string|function)
---@return boolean
local function normal_attach(prompt_bufnr, map)
  Util.validate({
    prompt_bufnr = { prompt_bufnr, { 'number' } },
    map = { map, { 'function' } },
  })

  local Keys = vim.deepcopy(Config.options.telescope.mappings) or {}

  if not Util.is_type('table', Keys) or vim.tbl_isempty(Keys) then
    Keys = vim.deepcopy(require('project.config.defaults').telescope.mappings)
  end

  for mode, group in pairs(Keys) do
    if vim.list_contains({ 'n', 'i' }, mode) and group and not vim.tbl_isempty(group) then
      group[mode == 'n' and '?' or '<C-?>'] = 'help_mappings'
      for lhs, act in pairs(group) do
        local rhs = vim.list_contains(valid_acts, act) and _Actions[act] or false ---@type function|false
        if rhs and vim.is_callable(rhs) and Util.is_type('string', lhs) then
          map(mode, lhs, rhs)
        end
      end
    end
  end

  Actions.select_default:replace(function()
    if Config.options.telescope.disable_file_picker then
      local entry = State.get_selected_entry()
      Api.set_pwd(entry.value, 'telescope')
      return require('telescope.actions.set').select(prompt_bufnr, 'default')
    end

    _Actions.find_project_files(prompt_bufnr)
  end)
  return true
end

---@param opts? table
function M.setup(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  M.default_opts = vim.tbl_deep_extend('keep', opts or {}, M.default_opts)
  vim.g.project_telescope_loaded = 1
end

---Main entrypoint for Telescope.
---
---CREDITS: https://github.com/ldfwbebp/project.nvim/commit/954b8371aa1e517f0d47d48b49373d2365cc92d3
--- ---
---@param opts? table
function M.projects(opts)
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })
  opts = opts or {}

  if vim.g.project_telescope_loaded ~= 1 then
    Log.error(('(%s.projects): Telescope picker not loaded!'):format(MODSTR))
    error(('(%s.projects): Telescope picker not loaded!'):format(MODSTR), ERROR)
  end

  local Options = Config.options
  local scope = Options.scope_chdir == 'win' and 'window' or Options.scope_chdir
  Pickers.new(vim.tbl_deep_extend('keep', opts, M.default_opts), {
    prompt_title = ('Select Your Project (%s)'):format(Util.capitalize(scope)),
    results_title = 'Projects',
    finder = _Util.create_finder(),
    previewer = false,
    sorter = telescope_config.generic_sorter(opts),
    attach_mappings = normal_attach,
  }):find()
end

local Main = setmetatable(M, { ---@type Project.Telescope.Main
  __index = M,
  __newindex = function()
    vim.notify('Project.Telescope.Main is Read-Only!', ERROR)
  end,
})

return Main
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
