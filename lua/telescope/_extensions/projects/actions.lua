assert(vim.g.project_setup == 1, '`project.nvim` is not loaded')

local Project = require('project')
assert(Project.util.mod_exists('telescope'), 'Telescope is not loaded')

---@class Project.ActionEntry
---@field display fun(entry: { name: string, value: string, display: function, index: integer, ordinal: string })
---@field name string
---@field ordinal string
---@field value string

---@class Project.Telescope.Actions
local M = {}

M.help_mappings = require('telescope.actions.generate').which_key({
  close_with_action = false,
  max_height = 0.6,
  name_width = 30,
  only_show_curret_mode = true,
  separator = ' | ',
})

---@param prompt_bufnr integer
function M.delete_project(prompt_bufnr)
  local State = require('telescope.actions.state')
  local picker = State.get_current_picker(prompt_bufnr)
  local multi = picker:get_multi_selection() ---@type Project.ActionEntry[]
  local entries = #multi > 0 and multi or { State.get_selected_entry() } --[[@as Project.ActionEntry[]\]]

  if #entries == 0 then
    require('telescope.actions').close(prompt_bufnr)
    Project.util.log.error(
      ('(telescope._extensions.projects.actions.delete_project): Entry not available!'):format(prompt_bufnr)
    )
  else
    local paths = {} ---@type string[]
    for _, entry in ipairs(entries) do
      if entry then
        table.insert(paths, Project.util.strip_slash(entry.value))
      end
    end

    Project.util.history.delete_projects(paths, true)
    Project.util.log.debug(
      ('(telescope._extensions.projects.actions.delete_project): Refreshing prompt `%s`.'):format(prompt_bufnr)
    )
    State.get_current_picker(prompt_bufnr):refresh(
      (function()
        local results = Project.util.history.get_recent_projects()
        if Project.config.get().telescope.sort == 'newest' then
          Project.util.log.debug('(telescope._extensions.projects.actions.delete_project): Sorting order to `newest`.')
          results = Project.util.reverse(results)
        end
        return require('telescope.finders').new_table({
          entry_maker = function(value) ---@param value ProjectHistoryEntry
            return { ---@type Project.ActionEntry
              display = require('telescope._extensions.projects.util').make_display,
              name = value.name,
              ordinal = ('%s %s'):format(
                value.name,
                require('telescope._extensions.projects.util').make_tilde(value.path)
              ),
              value = require('telescope._extensions.projects.util').make_tilde(value.path),
            }
          end,
          results = results,
        })
      end)(),
      { reset_prompt = true }
    )
  end
end

---@param prompt_bufnr integer
---@return string|nil|? value
---@return boolean|nil|? success
function M.change_cwd(prompt_bufnr)
  local selected_entry = require('telescope.actions.state').get_selected_entry() --[[@as Project.ActionEntry|nil|?]]
  require('telescope.actions').close(prompt_bufnr)
  Project.util.log.debug(
    ('(telescope._extensions.projects.actions.change_cwd): Closed prompt `%s`.'):format(prompt_bufnr)
  )

  assert(selected_entry ~= nil, 'Invalid entry')

  local cd_successful = Project.core.set_pwd({ dir = selected_entry.value, method = 'telescope' })
  if cd_successful then
    Project.util.log.debug('(telescope._extensions.projects.actions.change_cwd): Successfully changed directory.')
  else
    Project.util.log.error('(telescope._extensions.projects.actions.change_cwd): Failed to change directory!')
  end
  return selected_entry.value, cd_successful
end

---@param prompt_bufnr integer
function M.find_project_files(prompt_bufnr)
  local project_path, cd_successful = M.change_cwd(prompt_bufnr)
  if project_path and cd_successful then
    local Telescope = require('telescope')
    local opts = {
      path = project_path,
      cwd = project_path,
      cwd_to_path = true,
      hidden = Project.config.get().show_hidden,
      hide_parent_dir = true,
      mode = 'insert',
    }
    ---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/107
    (
      (Project.config.get().telescope.prefer_file_browser and Telescope.extensions.file_browser)
        and Telescope.extensions.file_browser.file_browser
      or require('telescope.builtin').find_files
    )(opts)
  end
end

---@param prompt_bufnr integer
function M.browse_project_files(prompt_bufnr)
  local cwd, cd_successful = M.change_cwd(prompt_bufnr)
  if cwd and cd_successful then
    local Telescope = require('telescope')
    local opts = {
      cwd = cwd,
      cwd_to_path = true,
      hidden = Project.config.get().show_hidden,
      hide_parent_dir = true,
      mode = 'insert',
      path = cwd,
    }
    ---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/107
    (
      (Project.config.get().telescope.prefer_file_browser and Telescope.extensions.file_browser)
        and Telescope.extensions.file_browser.file_browser
      or require('telescope.builtin').find_files
    )(opts)
  end
end

---@param prompt_bufnr integer
function M.search_in_project_files(prompt_bufnr)
  local cwd, cd_successful = M.change_cwd(prompt_bufnr)
  if cwd and cd_successful then
    require('telescope.builtin').live_grep({
      cwd = cwd,
      hidden = Project.config.get().show_hidden,
      mode = 'insert',
    })
  end
end

---@param prompt_bufnr integer
function M.rename_project(prompt_bufnr)
  Project.popup.rename_input(Project.util.strip_slash(require('telescope.actions.state').get_selected_entry().value))
  Project.util.log.debug(
    ('(telescope._extensions.projects.actions.rename_project): Refreshing prompt `%s`.'):format(prompt_bufnr)
  )
  require('telescope.actions').close(prompt_bufnr)
end

---@param prompt_bufnr integer
function M.recent_project_files(prompt_bufnr)
  local cwd, cd_successful = M.change_cwd(prompt_bufnr)
  if cd_successful and cwd then
    require('telescope.builtin').oldfiles({ cwd = cwd, cwd_only = true, hidden = Project.config.get().show_hidden })
  end
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
