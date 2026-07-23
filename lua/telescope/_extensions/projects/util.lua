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

  return Project.util.rstrip('/', vim.fn.fnamemodify(s, Project.config.get().telescope.tilde and ':p:~' or ':p'))
end

---@param entry { name: string, value: string, display: function, index: integer, ordinal: string }
function M.make_display(entry)
  Project.util.log.debug(
    ('(telescope._extensions.projects.util.make_display): Creating display. Entry values: %s'):format(
      vim.inspect(entry)
    )
  )
  return Entry_display.create({
    separator = ' ',
    items = { { width = 30 }, { remaining = true } },
  })({ entry.name, { entry.value, 'Comment' } })
end

function M.create_finder()
  local sort = Project.config.get().telescope.sort
  Project.util.log.info(('(telescope._extensions.projects.util.create_finder): Sorting by `%s`.'):format(sort))

  local results = Project.util.history.get_recent_projects()
  if sort == 'newest' then
    results = Project.util.reverse(results)
  end

  Project.util.log.debug('(telescope._extensions.projects.util.create_finder): Returning new Finder table.')
  return Finders.new_table({
    results = results,
    entry_maker = function(entry) ---@param entry ProjectHistoryEntry
      local name = entry.name
      return {
        display = M.make_display,
        name = name,
        value = M.make_tilde(entry.path),
        ordinal = ('%s %s'):format(name, M.make_tilde(entry.path)),
      }
    end,
  })
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
