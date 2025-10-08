local MODSTR = 'telescope._extensions.projects.util'
local ERROR = vim.log.levels.ERROR
if vim.g.project_setup ~= 1 then
    vim.notify(('(%s): `project.nvim` is not loaded!'):format(MODSTR), ERROR)
    return
end

local Log = require('project.utils.log')
if not require('project.utils.util').mod_exists('telescope') then
    Log.error(('(%s): Telescope is not installed!'):format(MODSTR))
    error(('(%s): Telescope is not installed!'):format(MODSTR), vim.log.levels.ERROR)
end
local Finders = require('telescope.finders')
local Entry_display = require('telescope.pickers.entry_display')

---@class Project.Telescope.Util
local M = {}

---@param entry { name: string, value: string, display: fun(...: any), index: integer, ordinal: string }
function M.make_display(entry)
    Log.debug(
        ('(%s.make_display): Creating display. Entry values: %s'):format(MODSTR, vim.inspect(entry))
    )
    local displayer = Entry_display.create({
        separator = ' ',
        items = {
            { width = 30 },
            { remaining = true },
        },
    })
    return displayer({ entry.name, { entry.value, 'Comment' } })
end

---@return table
function M.create_finder()
    local sort = require('project.config').options.telescope.sort
    local results = require('project.utils.history').get_recent_projects_v2()
    Log.info(('(%s.create_finder): Sorting by `%s`.'):format(MODSTR, sort))
    if sort == 'newest' then
        results = require('project.utils.util').reverse(results)
    end

    Log.debug(('(%s.create_finder): Returning new Finder table.'):format(MODSTR))
    return Finders.new_table({
        results = results,
        entry_maker = function(entry)
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

return M
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
