local MODSTR = 'telescope._extensions.projects.actions'
local ERROR = vim.log.levels.ERROR
if vim.g.project_setup ~= 1 then
  vim.notify(('(%s): `project.nvim` is not loaded!'):format(MODSTR), ERROR)
  return
end

local Project = require('project')
if not Project.util.mod_exists('telescope') then
  Project.util.log.error(('(%s): Telescope is not installed!'):format(MODSTR))
  vim.notify(('(%s): Telescope is not installed!'):format(MODSTR))
  return
end

local Telescope = require('telescope')
local Finders = require('telescope.finders')
local Actions = require('telescope.actions')
local Generate = require('telescope.actions.generate')
local Builtin = require('telescope.builtin')
local State = require('telescope.actions.state')
local make_display = require('telescope._extensions.projects.util').make_display
local make_tilde = require('telescope._extensions.projects.util').make_tilde

---@class Project.Telescope.Actions
local M = {}

M.help_mappings = Generate.which_key({
  only_show_curret_mode = true,
  name_width = 30,
  max_height = 0.6,
  separator = ' | ',
  close_with_action = false,
})

---@param prompt_bufnr integer
function M.delete_project(prompt_bufnr)
  local active_entry = State.get_selected_entry() ---@type Project.ActionEntry|nil
  if not active_entry then
    Actions.close(prompt_bufnr)
    Project.util.log.error(('(%s.delete_project): Entry not available!'):format(MODSTR, prompt_bufnr))
    return
  end

  Project.util.history.delete_project(Project.util.rstrip('/', vim.fn.fnamemodify(active_entry.value, ':p')), true)
  Project.util.log.debug(('(%s.delete_project): Refreshing prompt `%s`.'):format(MODSTR, prompt_bufnr))
  State.get_current_picker(prompt_bufnr):refresh(
    (function()
      local results = Project.util.history.get_recent_projects()
      if Project.config.options.telescope.sort == 'newest' then
        Project.util.log.debug(('(%s.delete_project): Sorting order to `newest`.'):format(MODSTR))
        results = Project.util.reverse(results)
      end
      return Finders.new_table({
        results = results,
        entry_maker = function(value) ---@param value string|ProjectHistoryEntry
          local name ---@type string
          if Project.util.history.legacy then
            ---@cast value string
            name = ('%s/%s'):format(vim.fn.fnamemodify(value, ':h:t'), vim.fn.fnamemodify(value, ':t'))
          else
            ---@cast value ProjectHistoryEntry
            name = value.name
          end
          local action_entry = { ---@class Project.ActionEntry
            display = make_display,
            name = name,
            value = make_tilde(Project.util.history.legacy and value or value.path),
            ordinal = ('%s %s'):format(name, make_tilde(Project.util.history.legacy and value or value.path)),
          }
          return action_entry
        end,
      })
    end)(),
    { reset_prompt = true }
  )
end

---@param prompt_bufnr integer
---@return string|nil
---@return boolean|nil
function M.change_working_directory(prompt_bufnr)
  local selected_entry = State.get_selected_entry() ---@type Project.ActionEntry
  Actions.close(prompt_bufnr)
  Project.util.log.debug(('(%s.change_working_directory): Closed prompt `%s`.'):format(MODSTR, prompt_bufnr))
  if not selected_entry then
    Project.util.log.error(('(%s.change_working_directory): Invalid entry!'):format(MODSTR))
    return
  end

  local cd_successful = Project.core.set_pwd(selected_entry.value, 'telescope')
  if cd_successful then
    Project.util.log.info(('(%s.change_working_directory): Successfully changed directory.'):format(MODSTR))
  else
    Project.util.log.error(('(%s.change_working_directory): Failed to change directory!'):format(MODSTR))
  end
  return selected_entry.value, cd_successful
end

---@param prompt_bufnr integer
function M.find_project_files(prompt_bufnr)
  local project_path, cd_successful = M.change_working_directory(prompt_bufnr)
  if not cd_successful then
    return
  end
  local opts = {
    path = project_path,
    cwd = project_path,
    cwd_to_path = true,
    hidden = Project.config.options.show_hidden,
    hide_parent_dir = true,
    mode = 'insert',
  }
  ---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/107
  if Project.config.options.telescope.prefer_file_browser and Telescope.extensions.file_browser then
    Telescope.extensions.file_browser.file_browser(opts)
    return
  end
  Builtin.find_files(opts)
end

---@param prompt_bufnr integer
function M.browse_project_files(prompt_bufnr)
  local project_path, cd_successful = M.change_working_directory(prompt_bufnr)
  if not cd_successful then
    return
  end
  local opts = {
    path = project_path,
    cwd = project_path,
    cwd_to_path = true,
    hidden = Project.config.options.show_hidden,
    hide_parent_dir = true,
    mode = 'insert',
  }
  ---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/107
  if Project.config.options.telescope.prefer_file_browser and Telescope.extensions.file_browser then
    Telescope.extensions.file_browser.file_browser(opts)
    return
  end
  Builtin.find_files(opts)
end

---@param prompt_bufnr integer
function M.search_in_project_files(prompt_bufnr)
  local project_path, cd_successful = M.change_working_directory(prompt_bufnr)
  if not cd_successful then
    return
  end
  Builtin.live_grep({ cwd = project_path, hidden = Project.config.options.show_hidden, mode = 'insert' })
end

---@param prompt_bufnr integer
function M.rename_project(prompt_bufnr)
  local active_entry = State.get_selected_entry() ---@type Project.ActionEntry
  Actions.close(prompt_bufnr)

  Project.popup.rename_input(Project.util.rstrip('/', vim.fn.fnamemodify(active_entry.value, ':p')))
  Project.util.log.debug(('(%s.r ename_project): Refreshing prompt `%s`.'):format(MODSTR, prompt_bufnr))
end

---@param prompt_bufnr integer
function M.recent_project_files(prompt_bufnr)
  local _, cd_successful = M.change_working_directory(prompt_bufnr)
  if not cd_successful then
    return
  end
  Builtin.oldfiles({ cwd_only = true, hidden = Project.config.options.show_hidden })
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
