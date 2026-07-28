local ERROR = vim.log.levels.ERROR
if vim.g.project_setup ~= 1 then
  vim.notify('(telescope._extensions.projects.util): `project.nvim` is not loaded!', ERROR)
  return
end

local Project = require('project')
if not Project.util.mod_exists('telescope') then
  Project.util.log.error('(telescope._extensions.projects.util): Telescope is not installed!')
  vim.notify('(telescope._extensions.projects.util): Telescope is not installed!', ERROR)
  return
end

local Finders = require('telescope.finders')
local Entry_display = require('telescope.pickers.entry_display')

---@class Project.Telescope.Util
local M = {}

---@param s string
---@return string tilde_str
function M.make_tilde(s)
  Project.util.validate({ s = { s, { 'string' } } })

  return Project.util.strip_slash(s, Project.config.get().telescope.tilde and ':p:~' or nil)
end

---@param entry { name: string, value: string, display: function, index: integer, ordinal: string }
function M.make_display(entry)
  Project.util.validate({ entry = { entry, { 'table' } } })

  return Entry_display.create({ separator = ' ', items = { { width = 30 }, { remaining = true } } })({
    entry.name,
    { entry.value, 'Comment' },
  })
end

function M.create_finder()
  local sort = Project.config.get().telescope.sort

  local results = Project.util.history.get_recent_projects()
  if sort == 'newest' then
    results = Project.util.reverse(results)
  end

  Project.util.log.debug(('(telescope._extensions.projects.util.create_finder): Sorting by `%s`.'):format(sort))
  Project.util.log.debug('(telescope._extensions.projects.util.create_finder): Returning new Finder table.')
  return Finders.new_table({
    results = results,
    entry_maker = function(entry) ---@param entry ProjectHistoryEntry
      return {
        display = M.make_display,
        name = entry.name,
        value = M.make_tilde(entry.path),
        ordinal = ('%s %s'):format(entry.name, M.make_tilde(entry.path)),
      }
    end,
  })
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
