local MODSTR = 'telescope._extensions.projects.util'
local ERROR = vim.log.levels.ERROR
if vim.g.project_setup ~= 1 then
  vim.notify(('(%s): `project.nvim` is not loaded!'):format(MODSTR), ERROR)
  return
end

local Log = require('project.util.log')
if not require('project.util').mod_exists('telescope') then
  Log.error(('(%s): Telescope is not installed!'):format(MODSTR))
  vim.notify(('(%s): Telescope is not installed!'):format(MODSTR), ERROR)
  return
end

local Util = require('project.util')
local Finders = require('telescope.finders')
local Entry_display = require('telescope.pickers.entry_display')

---@class Project.Telescope.Util
local M = {
  ---@param entry { name: string, value: string, display: function, index: integer, ordinal: string }
  make_display = function(entry)
    Log.debug(
      ('(%s.make_display): Creating display. Entry values: %s'):format(MODSTR, vim.inspect(entry))
    )
    return Entry_display.create({
      separator = ' ',
      items = { { width = 30 }, { remaining = true } },
    })({ entry.name, { entry.value, 'Comment' } })
  end,
}

function M.create_finder()
  local sort = require('project.config').options.telescope.sort
  Log.info(('(%s.create_finder): Sorting by `%s`.'):format(MODSTR, sort))

  local results = require('project.util.history').get_recent_projects()
  if sort == 'newest' then
    results = Util.reverse(results) ---@type string[]
  end

  Log.debug(('(%s.create_finder): Returning new Finder table.'):format(MODSTR))
  return Finders.new_table({
    results = results,
    entry_maker = function(entry) ---@param entry string
      local name = ('%s/%s'):format(
        vim.fn.fnamemodify(entry, ':h:t'),
        vim.fn.fnamemodify(entry, ':t')
      )
      return {
        display = M.make_display,
        name = name,
        value = entry,
        ordinal = ('%s %s'):format(name, entry),
      }
    end,
  })
end

local T_Util = setmetatable(M, { ---@type Project.Telescope.Util
  __index = M,
  __newindex = function()
    vim.notify('Project.Telescope.Util is Read-Only!', ERROR)
  end,
})

return T_Util
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
