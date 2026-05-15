local MODSTR = 'telescope._extensions.projects.util'
local ERROR = vim.log.levels.ERROR
if vim.g.project_setup ~= 1 then
  vim.notify(('(%s): `project.nvim` is not loaded!'):format(MODSTR), ERROR)
  return
end

local Project = require('project')
if not Project.util.mod_exists('telescope') then
  Project.util.log.error(('(%s): Telescope is not installed!'):format(MODSTR))
  vim.notify(('(%s): Telescope is not installed!'):format(MODSTR), ERROR)
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

  return Project.util.rstrip('/', vim.fn.fnamemodify(s, Project.config.options.telescope.tilde and ':p:~' or ':p'))
end

---@param entry { name: string, value: string, display: function, index: integer, ordinal: string }
function M.make_display(entry)
  Project.util.log.debug(('(%s.make_display): Creating display. Entry values: %s'):format(MODSTR, vim.inspect(entry)))
  return Entry_display.create({
    separator = ' ',
    items = { { width = 30 }, { remaining = true } },
  })({ entry.name, { entry.value, 'Comment' } })
end

function M.create_finder()
  local sort = Project.config.options.telescope.sort
  Project.util.log.info(('(%s.create_finder): Sorting by `%s`.'):format(MODSTR, sort))

  local results = Project.util.history.get_recent_projects()
  if sort == 'newest' then
    results = Project.util.reverse(results)
  end

  Project.util.log.debug(('(%s.create_finder): Returning new Finder table.'):format(MODSTR))
  return Finders.new_table({
    results = results,
    entry_maker = function(entry) ---@param entry string|ProjectHistoryEntry
      local name ---@type string
      if Project.util.history.legacy then
        ---@cast entry string
        name = ('%s/%s'):format(vim.fn.fnamemodify(entry, ':h:t'), vim.fn.fnamemodify(entry, ':t'))
      else
        ---@cast entry ProjectHistoryEntry
        name = entry.name
      end
      return {
        display = M.make_display,
        name = name,
        value = M.make_tilde(Project.util.history.legacy and entry or entry.path),
        ordinal = ('%s %s'):format(name, M.make_tilde(Project.util.history.legacy and entry or entry.path)),
      }
    end,
  })
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
