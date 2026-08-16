local ERROR = vim.log.levels.ERROR
if vim.g.project_setup ~= 1 then
  vim.notify('(telescope._extensions.projects.main): `project.nvim` is not loaded!', ERROR)
  return
end

local Project = require('project')
if not Project.util.mod_exists('telescope.init') then
  Project.util.log.error('(telescope._extensions.projects.main): Telescope is not installed!')
  vim.notify('(telescope._extensions.projects.main): Telescope is not installed!', ERROR)
  return
end

local _Actions = require('telescope._extensions.projects.actions')

---@class Project.Telescope.Main
---CREDITS: https://github.com/ldfwbebp/project.nvim/commit/954b8371aa1e517f0d47d48b49373d2365cc92d3
--- ---
---@field default_opts { prompt_prefix: string }
local M = {}

M.default_opts = { prompt_prefix = '󱎸  ' }

local valid_acts = {
  'browse_project_files',
  'change_cwd',
  'delete_project',
  'find_project_files',
  'help_mappings',
  'recent_project_files',
  'rename_project',
  'search_in_project_files',
}

---@param prompt_bufnr integer
---@param map fun(mode: string, lhs: string, rhs: string|function)
---@return boolean
---@nodiscard
local function normal_attach(prompt_bufnr, map)
  Project.util.validate({
    prompt_bufnr = { prompt_bufnr, { 'number' } },
    map = { map, { 'function' } },
  })

  local Keys = Project.config.get().telescope.mappings or {}
  if not Project.util.is_type('table', Keys) or vim.tbl_isempty(Keys) then
    Keys = require('project.config.defaults').telescope.mappings
  end

  for mode, group in pairs(Keys) do
    ---@cast group table<string, Project.Telescope.ActionNames>
    ---@cast mode 'i'|'n'
    if vim.list_contains({ 'n', 'i' }, mode) and group and not vim.tbl_isempty(group) then
      group[mode == 'n' and '?' or '<C-?>'] = 'help_mappings'
      for lhs, act in pairs(group) do
        local rhs = vim.list_contains(valid_acts, act) and _Actions[act] or false ---@type function|false
        if rhs and vim.is_callable(rhs) and Project.util.is_type('string', lhs) then
          map(mode, lhs, rhs)
        end
      end
    end
  end

  require('telescope.actions').select_default:replace(function()
    local config = Project.config.get()
    Project.core.set_pwd(require('telescope.actions.state').get_selected_entry().value, 'telescope')
    if config.telescope.behavior == 'explore' then
      if config.telescope.disable_file_picker then
        return require('telescope.actions.set').select(prompt_bufnr, 'default')
      end

      _Actions.find_project_files(prompt_bufnr)
    else
      _Actions.recent_project_files(prompt_bufnr)
    end
  end)
  return true
end

---@param opts? table
function M.setup(opts)
  Project.util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  M.default_opts = vim.tbl_deep_extend('keep', opts or {}, M.default_opts)
  vim.g.project_telescope_loaded = 1
end

---Main entrypoint for Telescope.
---
---CREDITS: https://github.com/ldfwbebp/project.nvim/commit/954b8371aa1e517f0d47d48b49373d2365cc92d3
--- ---
---@param opts? table
function M.projects(opts)
  Project.util.validate({ opts = { opts, { 'table', 'nil' }, true } })
  opts = opts or {}

  if vim.g.project_telescope_loaded ~= 1 then
    Project.util.log.error('(telescope._extensions.projects.main.projects): Telescope picker not loaded!')
    error('(telescope._extensions.projects.main.projects): Telescope picker not loaded!')
  end

  local scope_chdir = Project.config.get().scope_chdir
  require('telescope.pickers')
    .new(vim.tbl_deep_extend('keep', opts, M.default_opts), {
      attach_mappings = normal_attach,
      finder = require('telescope._extensions.projects.util').create_finder(),
      previewer = false,
      prompt_title = ('Select Your Project (%s)'):format(
        Project.util.capitalize(scope_chdir == 'win' and 'window' or scope_chdir)
      ),
      results_title = 'Projects',
      sorter = require('telescope.config').values.generic_sorter(opts),
    })
    :find()
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
